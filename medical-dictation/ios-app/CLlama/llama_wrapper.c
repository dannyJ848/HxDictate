//
//  llama_wrapper.c
//  HxDictate
//
//  C wrapper to simplify Swift interop with llama.cpp
//

#include "include/llama_wrapper.h"
#include "llama.h"

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

// MARK: - Backend Management

void llama_wrapper_backend_init(void) {
    llama_backend_init();
}

void llama_wrapper_backend_free(void) {
    llama_backend_free();
}

// MARK: - Model Management

static bool progress_callback_wrapper(float progress, void *user_data) {
    llama_wrapper_progress_callback cb = (llama_wrapper_progress_callback)user_data;
    if (cb) {
        return cb(progress, NULL);
    }
    return true;
}

struct llama_model *llama_wrapper_load_model(const char *path_model,
                                              int32_t n_gpu_layers,
                                              llama_wrapper_progress_callback progress_callback,
                                              void *user_data) {
    struct llama_model_params params = llama_model_default_params();
    params.n_gpu_layers = n_gpu_layers;
    params.use_mmap = false;  // Disable mmap for iOS - causes memory issues
    params.use_mlock = false;
    
    if (progress_callback) {
        params.progress_callback = progress_callback_wrapper;
        params.progress_callback_user_data = progress_callback;
    }
    
    return llama_model_load_from_file(path_model, params);
}

void llama_wrapper_free_model(struct llama_model *model) {
    if (model) {
        llama_model_free(model);
    }
}

int32_t llama_wrapper_model_desc(struct llama_model *model, char *buf, size_t buf_size) {
    if (!model || !buf || buf_size == 0) return 0;
    return llama_model_desc(model, buf, buf_size);
}

// MARK: - Context Management

struct llama_context *llama_wrapper_new_context(struct llama_model *model,
                                                 uint32_t n_ctx,
                                                 int32_t n_threads,
                                                 int32_t n_threads_batch) {
    if (!model) return NULL;
    
    struct llama_context_params params = llama_context_default_params();
    params.n_ctx = n_ctx > 0 ? n_ctx : 4096;
    params.n_batch = 512;
    params.n_ubatch = 512;
    params.n_threads = n_threads > 0 ? n_threads : 4;
    params.n_threads_batch = n_threads_batch > 0 ? n_threads_batch : params.n_threads;
    params.offload_kqv = true;
    
    return llama_init_from_model(model, params);
}

void llama_wrapper_free_context(struct llama_context *ctx) {
    if (ctx) {
        llama_free(ctx);
    }
}

struct llama_vocab *llama_wrapper_get_vocab(struct llama_model *model) {
    if (!model) return NULL;
    return llama_model_get_vocab(model);
}

// MARK: - Tokenization

int32_t llama_wrapper_tokenize(struct llama_vocab *vocab,
                                const char *text,
                                int32_t text_len,
                                llama_token *tokens,
                                int32_t n_tokens_max,
                                bool add_special) {
    if (!vocab || !text || !tokens || n_tokens_max <= 0) return -1;
    
    int32_t len = text_len >= 0 ? text_len : (int32_t)strlen(text);
    return llama_tokenize(vocab, text, len, tokens, n_tokens_max, add_special, false);
}

int32_t llama_wrapper_token_to_piece(struct llama_vocab *vocab,
                                      llama_token token,
                                      char *buf,
                                      int32_t buf_len) {
    if (!vocab || !buf || buf_len <= 0) return -1;
    
    int32_t result = llama_token_to_piece(vocab, token, buf, buf_len, 0, false);
    
    // If buffer is too small, allocate a larger one
    if (result < 0) {
        int32_t needed = -result;
        char *temp = (char *)malloc(needed);
        if (!temp) return -1;
        
        result = llama_token_to_piece(vocab, token, temp, needed, 0, false);
        if (result > 0) {
            int32_t to_copy = result < buf_len ? result : buf_len - 1;
            memcpy(buf, temp, to_copy);
            buf[to_copy] = '\0';
        }
        free(temp);
    }
    
    return result;
}

bool llama_wrapper_is_eog(struct llama_vocab *vocab, llama_token token) {
    if (!vocab) return false;
    return llama_vocab_is_eog(vocab, token);
}

llama_token llama_wrapper_get_bos_token(struct llama_vocab *vocab) {
    if (!vocab) return -1;
    return llama_vocab_bos(vocab);
}

llama_token llama_wrapper_get_eos_token(struct llama_vocab *vocab) {
    if (!vocab) return -1;
    return llama_vocab_eos(vocab);
}

// MARK: - Sampler Helpers

static struct llama_sampler *create_sampler(struct llama_vocab *vocab, struct llama_sampler_config config) {
    struct llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    struct llama_sampler *smpl = llama_sampler_chain_init(sparams);
    
    if (!smpl) return NULL;
    
    // Add repetition penalty if configured
    if (config.repeat_penalty != 1.0f && config.repeat_last_n > 0) {
        llama_sampler_chain_add(smpl, llama_sampler_init_penalties(
            config.repeat_last_n,
            config.repeat_penalty,
            0.0f,  // freq penalty
            0.0f   // present penalty
        ));
    }
    
    // Add top-k sampling
    if (config.top_k > 0) {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(config.top_k));
    }
    
    // Add top-p (nucleus) sampling
    if (config.top_p < 1.0f) {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(config.top_p, 1));
    }
    
    // Add min-p sampling
    if (config.min_p > 0.0f) {
        llama_sampler_chain_add(smpl, llama_sampler_init_min_p(config.min_p, 1));
    }
    
    // Add temperature
    float temp = config.temperature > 0.0f ? config.temperature : 0.8f;
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(temp));
    
    // Add distribution sampler (always last)
    uint32_t seed = config.seed != 0 ? config.seed : (uint32_t)time(NULL);
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(seed));
    
    return smpl;
}

struct llama_sampler_config llama_wrapper_default_sampler_config(void) {
    struct llama_sampler_config config = {
        .temperature = 0.7f,
        .top_k = 40,
        .top_p = 0.9f,
        .min_p = 0.05f,
        .seed = 0,
        .repeat_penalty = 1.1f,
        .repeat_last_n = 64
    };
    return config;
}

// MARK: - Batch Processing

int32_t llama_wrapper_decode_batch(struct llama_context *ctx,
                                    const llama_token *tokens,
                                    int32_t n_tokens) {
    if (!ctx || !tokens || n_tokens <= 0) return -1;
    
    struct llama_batch batch = llama_batch_init(n_tokens, 0, 1);
    if (!batch.token) return -1;
    
    for (int32_t i = 0; i < n_tokens; i++) {
        batch.token[i] = tokens[i];
        batch.pos[i] = i;
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = 0;
    }
    
    // Only compute logits for the last token
    batch.logits[n_tokens - 1] = 1;
    batch.n_tokens = n_tokens;
    
    int32_t result = llama_decode(ctx, batch);
    llama_batch_free(batch);
    
    return result;
}

llama_token llama_wrapper_sample_token(struct llama_context *ctx,
                                        struct llama_vocab *vocab,
                                        struct llama_sampler_config config) {
    if (!ctx || !vocab) return -1;
    
    struct llama_sampler *smpl = create_sampler(vocab, config);
    if (!smpl) return -1;
    
    llama_token token = llama_sampler_sample(smpl, ctx, -1);
    llama_sampler_free(smpl);
    
    return token;
}

// MARK: - Generation

int32_t llama_wrapper_generate(struct llama_context *ctx,
                                struct llama_vocab *vocab,
                                const char *prompt,
                                int32_t max_tokens,
                                struct llama_sampler_config config,
                                llama_wrapper_token_callback token_callback,
                                void *user_data,
                                char *output_buffer,
                                size_t output_buffer_size) {
    if (!ctx || !vocab || !prompt || max_tokens <= 0) return -1;
    
    // Tokenize the prompt
    int32_t prompt_len = (int32_t)strlen(prompt);
    int32_t n_tokens_estimate = prompt_len + 4;  // Rough estimate
    llama_token *prompt_tokens = (llama_token *)malloc(n_tokens_estimate * sizeof(llama_token));
    if (!prompt_tokens) return -1;
    
    int32_t n_prompt_tokens = llama_tokenize(vocab, prompt, prompt_len, prompt_tokens, n_tokens_estimate, true, false);
    
    // If buffer was too small, retry with larger buffer
    if (n_prompt_tokens < 0) {
        n_tokens_estimate = -n_prompt_tokens;
        prompt_tokens = (llama_token *)realloc(prompt_tokens, n_tokens_estimate * sizeof(llama_token));
        if (!prompt_tokens) return -1;
        n_prompt_tokens = llama_tokenize(vocab, prompt, prompt_len, prompt_tokens, n_tokens_estimate, true, false);
    }
    
    if (n_prompt_tokens < 0) {
        free(prompt_tokens);
        return -1;
    }
    
    // Check context size
    uint32_t n_ctx = llama_n_ctx(ctx);
    if ((uint32_t)n_prompt_tokens + max_tokens > n_ctx) {
        max_tokens = (int32_t)n_ctx - n_prompt_tokens;
        if (max_tokens <= 0) {
            free(prompt_tokens);
            return -1;
        }
    }
    
    // Process prompt in batches
    int32_t pos = 0;
    int32_t remaining = n_prompt_tokens;
    
    while (remaining > 0) {
        int32_t batch_size = remaining < 512 ? remaining : 512;
        
        struct llama_batch batch = llama_batch_init(batch_size, 0, 1);
        if (!batch.token) {
            free(prompt_tokens);
            return -1;
        }
        
        for (int32_t i = 0; i < batch_size; i++) {
            batch.token[i] = prompt_tokens[pos + i];
            batch.pos[i] = pos + i;
            batch.n_seq_id[i] = 1;
            batch.seq_id[i][0] = 0;
            batch.logits[i] = 0;
        }
        
        // Only compute logits for the last token of the final batch
        batch.logits[batch_size - 1] = (remaining == batch_size) ? 1 : 0;
        batch.n_tokens = batch_size;
        
        int32_t result = llama_decode(ctx, batch);
        llama_batch_free(batch);
        
        if (result != 0) {
            free(prompt_tokens);
            return -1;
        }
        
        pos += batch_size;
        remaining -= batch_size;
    }
    
    free(prompt_tokens);
    
    // Create sampler
    struct llama_sampler *smpl = create_sampler(vocab, config);
    if (!smpl) return -1;
    
    // Generation loop
    int32_t n_generated = 0;
    size_t output_pos = 0;
    llama_token prev_token = -1;
    
    // Buffer for incomplete UTF-8 sequences
    char incomplete_buf[8] = {0};
    int32_t incomplete_len = 0;
    
    while (n_generated < max_tokens) {
        // Sample next token
        llama_token new_token = llama_sampler_sample(smpl, ctx, -1);
        
        // Accept the token for repetition penalty
        llama_sampler_accept(smpl, new_token);
        
        // Check for end of generation
        if (llama_vocab_is_eog(vocab, new_token)) {
            break;
        }
        
        // Convert token to piece
        char piece_buf[32];
        int32_t piece_len = llama_token_to_piece(vocab, new_token, piece_buf, sizeof(piece_buf), 0, false);
        
        if (piece_len > 0) {
            // Handle incomplete UTF-8
            if (incomplete_len > 0) {
                memcpy(incomplete_buf + incomplete_len, piece_buf, piece_len < (size_t)(8 - incomplete_len) ? piece_len : (8 - incomplete_len));
                incomplete_len += piece_len;
                
                // Try to decode
                if (incomplete_len >= 0) {
                    // Simple check: if first byte indicates multi-byte sequence
                    unsigned char first = (unsigned char)incomplete_buf[0];
                    int expected = 1;
                    if ((first & 0xE0) == 0xC0) expected = 2;
                    else if ((first & 0xF0) == 0xE0) expected = 3;
                    else if ((first & 0xF8) == 0xF0) expected = 4;
                    
                    if (incomplete_len >= expected) {
                        // We have a complete character
                        if (token_callback) {
                            incomplete_buf[incomplete_len] = '\0';
                            token_callback(incomplete_buf, user_data);
                        }
                        
                        // Add to output buffer
                        if (output_buffer && output_pos + incomplete_len < output_buffer_size) {
                            memcpy(output_buffer + output_pos, incomplete_buf, incomplete_len);
                            output_pos += incomplete_len;
                            output_buffer[output_pos] = '\0';
                        }
                        
                        incomplete_len = 0;
                    }
                }
            } else {
                // Check if this starts a multi-byte UTF-8 sequence
                unsigned char first = (unsigned char)piece_buf[0];
                bool is_multibyte = ((first & 0xE0) == 0xC0) ||  // 2-byte
                                   ((first & 0xF0) == 0xE0) ||  // 3-byte
                                   ((first & 0xF8) == 0xF0);    // 4-byte
                
                if (is_multibyte && piece_len == 1) {
                    // Start of multi-byte sequence but incomplete
                    incomplete_buf[0] = piece_buf[0];
                    incomplete_len = 1;
                } else {
                    // Complete token
                    piece_buf[piece_len] = '\0';
                    
                    if (token_callback) {
                        token_callback(piece_buf, user_data);
                    }
                    
                    if (output_buffer && output_pos + piece_len < output_buffer_size) {
                        memcpy(output_buffer + output_pos, piece_buf, piece_len);
                        output_pos += piece_len;
                        output_buffer[output_pos] = '\0';
                    }
                }
            }
        }
        
        prev_token = new_token;
        n_generated++;
        
        // Prepare next batch with single token
        struct llama_batch batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(ctx, batch) != 0) {
            break;
        }
    }
    
    // Flush any remaining incomplete UTF-8
    if (incomplete_len > 0 && output_buffer && output_pos + incomplete_len < output_buffer_size) {
        memcpy(output_buffer + output_pos, incomplete_buf, incomplete_len);
        output_buffer[output_pos + incomplete_len] = '\0';
    }
    
    llama_sampler_free(smpl);
    
    return n_generated;
}

void llama_wrapper_clear_kv_cache(struct llama_context *ctx) {
    if (ctx) {
        llama_memory_clear(llama_get_memory(ctx), true);
    }
}

// MARK: - Utility

uint32_t llama_wrapper_n_ctx(const struct llama_context *ctx) {
    if (!ctx) return 0;
    return llama_n_ctx(ctx);
}

int32_t llama_wrapper_n_vocab(const struct llama_vocab *vocab) {
    if (!vocab) return 0;
    return llama_vocab_n_tokens(vocab);
}
