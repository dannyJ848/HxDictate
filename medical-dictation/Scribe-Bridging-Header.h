//
//  Scribe-Bridging-Header.h
//  Scribe
//
//  Bridging header for C++ libraries
//

#ifndef Scribe_Bridging_Header_h
#define Scribe_Bridging_Header_h

#import <Foundation/Foundation.h>

// MARK: - whisper.cpp function declarations
struct whisper_context;
struct whisper_full_params;
struct whisper_context_params;

typedef int whisper_token;

enum whisper_sampling_strategy {
    WHISPER_SAMPLING_GREEDY,
    WHISPER_SAMPLING_BEAM_SEARCH,
};

// Function declarations
struct whisper_context * whisper_init_from_file_with_params(const char * path, struct whisper_context_params params);
void whisper_free(struct whisper_context * ctx);
struct whisper_full_params whisper_full_default_params(enum whisper_sampling_strategy strategy);
struct whisper_context_params whisper_context_default_params(void);
int whisper_full(struct whisper_context * ctx, struct whisper_full_params params, const float * samples, int n_samples);
int whisper_full_n_segments(const struct whisper_context * ctx);
const char * whisper_full_get_segment_text(const struct whisper_context * ctx, int segment);

// Params structures
struct whisper_context_params {
    int use_gpu;
    int flash_attn;
};

struct whisper_full_params {
    enum whisper_sampling_strategy strategy;
    int n_threads;
    int translate;
    int no_context;
    int no_timestamps;
    const char * language;
    int detect_language;
    float temperature;
};

// MARK: - llama.cpp function declarations
typedef int llama_token;
typedef int llama_pos;
struct llama_model;
struct llama_context;
struct llama_batch;

struct llama_model_params {
    int n_gpu_layers;
    int use_mmap;
    int use_mlock;
};

struct llama_context_params {
    unsigned int seed;
    unsigned int n_ctx;
    unsigned int n_batch;
    unsigned int n_threads;
    unsigned int n_threads_batch;
    int logits_all;
    int embeddings;
    int flash_attn;
};

struct llama_batch {
    int n_tokens;
    llama_token * token;
    llama_pos * pos;
    char * logits;
};

// Function declarations
struct llama_model * llama_load_model_from_file(const char * path_model, struct llama_model_params params);
void llama_free_model(struct llama_model * model);
struct llama_context * llama_new_context_with_model(struct llama_model * model, struct llama_context_params params);
void llama_free(struct llama_context * ctx);
struct llama_model_params llama_model_default_params(void);
struct llama_context_params llama_context_default_params(void);
int llama_tokenize(const struct llama_model * model, const char * text, int text_len, llama_token * tokens, int n_max_tokens, int add_special, int parse_special);
int llama_token_to_piece(const struct llama_model * model, llama_token token, char * buf, int length, int lstrip, int special);
int llama_decode(struct llama_context * ctx, struct llama_batch batch);
float * llama_get_logits(struct llama_context * ctx);
float * llama_get_logits_ith(struct llama_context * ctx, int i);
llama_token llama_token_eos(const struct llama_model * model);
const struct llama_model * llama_get_model(const struct llama_context * ctx);
int llama_n_vocab(const struct llama_model * model);
int llama_n_ctx(const struct llama_context * ctx);
struct llama_batch llama_batch_init(int n_tokens_alloc, int embd, int n_seq_max);
void llama_batch_free(struct llama_batch batch);

#endif /* Scribe_Bridging_Header_h */
