//
//  Scribe-Bridging-Header.h
//  Scribe
//
//  Bridging header for C++ libraries
//

#ifndef Scribe_Bridging_Header_h
#define Scribe_Bridging_Header_h

#import <Foundation/Foundation.h>

// Use proper C types for Objective-C
#define bool BOOL
#define true YES
#define false NO

// MARK: - whisper.cpp
struct whisper_context;
struct whisper_full_params;
struct whisper_context_params;

typedef int whisper_token;
typedef int whisper_segment;

enum whisper_sampling_strategy {
    WHISPER_SAMPLING_GREEDY,
    WHISPER_SAMPLING_BEAM_SEARCH,
};

extern "C" {
    struct whisper_context * whisper_init_from_file_with_params(const char * path, struct whisper_context_params params);
    void whisper_free(struct whisper_context * ctx);
    struct whisper_full_params whisper_full_default_params(enum whisper_sampling_strategy strategy);
    struct whisper_context_params whisper_context_default_params(void);
    int whisper_full(struct whisper_context * ctx, struct whisper_full_params params, const float * samples, int n_samples);
    int whisper_full_n_segments(const struct whisper_context * ctx);
    const char * whisper_full_get_segment_text(const struct whisper_context * ctx, int segment);
}

struct whisper_context_params {
    BOOL use_gpu;
    BOOL flash_attn;
};

struct whisper_full_params {
    enum whisper_sampling_strategy strategy;
    int n_threads;
    int n_max_text_ctx;
    int offset_ms;
    int duration_ms;
    BOOL translate;
    BOOL no_context;
    BOOL no_timestamps;
    BOOL single_segment;
    const char * language;
    BOOL detect_language;
    BOOL suppress_blank;
    float temperature;
};

// MARK: - llama.cpp
typedef int llama_token;
typedef int llama_pos;
struct llama_model;
struct llama_context;
struct llama_batch;

enum llama_rope_scaling_type {
    LLAMA_ROPE_SCALING_TYPE_UNSPECIFIED = -1,
    LLAMA_ROPE_SCALING_TYPE_NONE = 0,
    LLAMA_ROPE_SCALING_TYPE_LINEAR = 1,
    LLAMA_ROPE_SCALING_TYPE_YARN = 2,
};

struct llama_model_params {
    int n_gpu_layers;
    BOOL use_mmap;
    BOOL use_mlock;
    BOOL check_tensors;
};

struct llama_context_params {
    uint32_t seed;
    uint32_t n_ctx;
    uint32_t n_batch;
    uint32_t n_threads;
    uint32_t n_threads_batch;
    BOOL logits_all;
    BOOL embeddings;
    BOOL offload_kqv;
    BOOL flash_attn;
};

struct llama_batch {
    int32_t n_tokens;
    llama_token * token;
    llama_pos * pos;
    int8_t * logits;
};

extern "C" {
    struct llama_model * llama_load_model_from_file(const char * path_model, struct llama_model_params params);
    void llama_free_model(struct llama_model * model);
    struct llama_context * llama_new_context_with_model(struct llama_model * model, struct llama_context_params params);
    void llama_free(struct llama_context * ctx);
    struct llama_model_params llama_model_default_params(void);
    struct llama_context_params llama_context_default_params(void);
    int32_t llama_tokenize(const struct llama_model * model, const char * text, int32_t text_len, llama_token * tokens, int32_t n_max_tokens, BOOL add_special, BOOL parse_special);
    int32_t llama_decode(struct llama_context * ctx, struct llama_batch batch);
    float * llama_get_logits(struct llama_context * ctx);
    llama_token llama_token_eos(const struct llama_model * model);
    int32_t llama_n_vocab(const struct llama_model * model);
}

#undef bool
#undef true
#undef false

#endif /* Scribe_Bridging_Header_h */
