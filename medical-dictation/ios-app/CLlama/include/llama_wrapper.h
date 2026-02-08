//
//  llama_wrapper.h
//  HxDictate
//
//  C wrapper header for llama.cpp
//

#ifndef llama_wrapper_h
#define llama_wrapper_h

#include <stdint.h>
#include <stdbool.h>

// Opaque types for Swift interop
struct llama_model;
struct llama_context;
struct llama_vocab;
struct llama_sampler;

// Token type
typedef int32_t llama_token;

// Progress callback type
typedef bool (*llama_wrapper_progress_callback)(float progress, void *user_data);

// Token callback type - called for each generated token
typedef void (*llama_wrapper_token_callback)(const char *token_text, void *user_data);

// MARK: - Backend Management

/// Initialize llama backend (call once at app startup)
void llama_wrapper_backend_init(void);

/// Free llama backend (call once at app shutdown)
void llama_wrapper_backend_free(void);

// MARK: - Model Management

/// Load a model from file
/// @param path_model Path to the .gguf model file
/// @param n_gpu_layers Number of layers to offload to GPU (-1 for all, 0 for none)
/// @param progress_callback Optional callback for loading progress
/// @param user_data User data passed to callback
/// @return Pointer to model or NULL on error
struct llama_model *llama_wrapper_load_model(const char *path_model,
                                              int32_t n_gpu_layers,
                                              llama_wrapper_progress_callback progress_callback,
                                              void *user_data);

/// Free a loaded model
void llama_wrapper_free_model(struct llama_model *model);

/// Get model description
/// @param model The model
/// @param buf Buffer to store description
/// @param buf_size Buffer size
/// @return Number of characters written
int32_t llama_wrapper_model_desc(struct llama_model *model, char *buf, size_t buf_size);

// MARK: - Context Management

/// Create a context from a loaded model
/// @param model The loaded model
/// @param n_ctx Context window size (0 for model default)
/// @param n_threads Number of threads for generation
/// @param n_threads_batch Number of threads for batch processing
/// @return Pointer to context or NULL on error
struct llama_context *llama_wrapper_new_context(struct llama_model *model,
                                                 uint32_t n_ctx,
                                                 int32_t n_threads,
                                                 int32_t n_threads_batch);

/// Free a context
void llama_wrapper_free_context(struct llama_context *ctx);

/// Get the vocab from a model
struct llama_vocab *llama_wrapper_get_vocab(struct llama_model *model);

// MARK: - Tokenization

/// Tokenize text
/// @param vocab The vocabulary
/// @param text Text to tokenize
/// @param text_len Length of text (-1 for null-terminated)
/// @param tokens Output token array
/// @param n_tokens_max Maximum number of tokens to write
/// @param add_special Whether to add BOS/EOS tokens
/// @return Number of tokens (negative on error)
int32_t llama_wrapper_tokenize(struct llama_vocab *vocab,
                                const char *text,
                                int32_t text_len,
                                llama_token *tokens,
                                int32_t n_tokens_max,
                                bool add_special);

/// Convert a token to text
/// @param vocab The vocabulary
/// @param token The token to convert
/// @param buf Output buffer
/// @param buf_len Buffer length
/// @return Number of characters written (negative if buffer too small)
int32_t llama_wrapper_token_to_piece(struct llama_vocab *vocab,
                                      llama_token token,
                                      char *buf,
                                      int32_t buf_len);

/// Check if token is end-of-generation
bool llama_wrapper_is_eog(struct llama_vocab *vocab, llama_token token);

/// Get the BOS token
llama_token llama_wrapper_get_bos_token(struct llama_vocab *vocab);

/// Get the EOS token
llama_token llama_wrapper_get_eos_token(struct llama_vocab *vocab);

// MARK: - Generation

/// Sampler configuration
struct llama_sampler_config {
    float temperature;      // Sampling temperature (0.0 = greedy)
    int32_t top_k;         // Top-k sampling (0 = disabled)
    float top_p;           // Top-p (nucleus) sampling (1.0 = disabled)
    float min_p;           // Min-p sampling (0.0 = disabled)
    uint32_t seed;         // Random seed (0 = random)
    float repeat_penalty;  // Repetition penalty (1.0 = disabled)
    int32_t repeat_last_n; // Number of tokens to consider for repetition penalty
};

/// Get default sampler config
struct llama_sampler_config llama_wrapper_default_sampler_config(void);

/// Generate text from a prompt
/// @param ctx The context
/// @param vocab The vocabulary
/// @param prompt The prompt text
/// @param max_tokens Maximum number of tokens to generate
/// @param config Sampler configuration
/// @param token_callback Called for each generated token (can be NULL)
/// @param user_data User data passed to callback
/// @param output_buffer Buffer to store full output
/// @param output_buffer_size Size of output buffer
/// @return Number of tokens generated (negative on error)
int32_t llama_wrapper_generate(struct llama_context *ctx,
                                struct llama_vocab *vocab,
                                const char *prompt,
                                int32_t max_tokens,
                                struct llama_sampler_config config,
                                llama_wrapper_token_callback token_callback,
                                void *user_data,
                                char *output_buffer,
                                size_t output_buffer_size);

/// Clear the KV cache
void llama_wrapper_clear_kv_cache(struct llama_context *ctx);

// MARK: - Batch Processing

/// Process a batch of tokens (prompt processing)
/// @param ctx The context
/// @param tokens Array of tokens
/// @param n_tokens Number of tokens
/// @return 0 on success, non-zero on error
int32_t llama_wrapper_decode_batch(struct llama_context *ctx,
                                    const llama_token *tokens,
                                    int32_t n_tokens);

/// Sample a single token
/// @param ctx The context
/// @param vocab The vocabulary
/// @param config Sampler configuration
/// @return The sampled token
llama_token llama_wrapper_sample_token(struct llama_context *ctx,
                                        struct llama_vocab *vocab,
                                        struct llama_sampler_config config);

// MARK: - Utility

/// Get context size
uint32_t llama_wrapper_n_ctx(const struct llama_context *ctx);

/// Get vocab size
int32_t llama_wrapper_n_vocab(const struct llama_vocab *vocab);

#endif /* llama_wrapper_h */
