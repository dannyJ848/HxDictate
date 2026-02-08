//
//  Scribe-Bridging-Header.h
//  Scribe
//
//  Bridging header for C++ libraries
//

#ifndef Scribe_Bridging_Header_h
#define Scribe_Bridging_Header_h

// MARK: - whisper.cpp
// Include path: build/whisper.cpp/include

// Forward declarations for whisper types
struct whisper_context;
struct whisper_full_params;

typedef int whisper_token;
typedef int whisper_segment;

enum whisper_sampling_strategy {
    WHISPER_SAMPLING_GREEDY,
    WHISPER_SAMPLING_BEAM_SEARCH,
};

// C function declarations
extern "C" {
    // Context management
    struct whisper_context * whisper_init_from_file_with_params(const char * path, struct whisper_context_params params);
    struct whisper_context * whisper_init_from_buffer_with_params(const void * buffer, size_t buffer_size, struct whisper_context_params params);
    void whisper_free(struct whisper_context * ctx);
    
    // Parameters
    struct whisper_full_params whisper_full_default_params(enum whisper_sampling_strategy strategy);
    struct whisper_context_params whisper_context_default_params(void);
    
    // Transcription
    int whisper_full(struct whisper_context * ctx, struct whisper_full_params params, const float * samples, int n_samples);
    int whisper_full_parallel(struct whisper_context * ctx, struct whisper_full_params params, const float * samples, int n_samples, int n_processors);
    
    // Results
    int whisper_full_n_segments(const struct whisper_context * ctx);
    int whisper_full_n_tokens(const struct whisper_context * ctx, int segment);
    const char * whisper_full_get_segment_text(const struct whisper_context * ctx, int segment);
    const char * whisper_full_get_token_text(const struct whisper_context * ctx, int segment, int token);
    int64_t whisper_full_get_segment_t0(const struct whisper_context * ctx, int segment);
    int64_t whisper_full_get_segment_t1(const struct whisper_context * ctx, int segment);
    
    // Utility
    int whisper_lang_id(const char * lang);
    int whisper_lang_auto_detect(struct whisper_context * ctx, int offset_ms, int n_threads, float * lang_probs);
}

// Params structures (simplified)
struct whisper_context_params {
    bool use_gpu;
    bool flash_attn;
};

struct whisper_full_params {
    enum whisper_sampling_strategy strategy;
    int n_threads;
    int n_max_text_ctx;
    int offset_ms;
    int duration_ms;
    bool translate;
    bool no_context;
    bool no_timestamps;
    bool single_segment;
    bool print_special;
    bool print_progress;
    bool print_realtime;
    bool print_timestamps;
    bool token_timestamps;
    float thold_pt;
    float thold_ptsum;
    int max_len;
    bool split_on_word;
    int max_tokens;
    bool speed_up;
    bool debug_mode;
    int audio_ctx;
    const char * initial_prompt;
    const char * prompt_tokens;
    int prompt_n_tokens;
    const char * language;
    bool detect_language;
    bool suppress_blank;
    float temperature;
    float max_initial_ts;
    float length_penalty;
    float temperature_inc;
    float entropy_thold;
    float logprob_thold;
    float no_speech_thold;
    struct {
        int n_past;
    } greedy;
    struct {
        int n_past;
        int beam_size;
        int patience;
    } beam_search;
};

// MARK: - llama.cpp
// Include path: build/llama.cpp/include

// Forward declarations
typedef int llama_token;
typedef int llama_pos;
struct llama_model;
struct llama_context;
struct llama_batch;

// Enums
enum llama_vocab_type {
    LLAMA_VOCAB_TYPE_SPM = 0,
    LLAMA_VOCAB_TYPE_BPE = 1,
    LLAMA_VOCAB_TYPE_WPM = 2,
    LLAMA_VOCAB_TYPE_UGM = 3,
    LLAMA_VOCAB_TYPE_RWKV = 4,
};

enum llama_rope_scaling_type {
    LLAMA_ROPE_SCALING_TYPE_UNSPECIFIED = -1,
    LLAMA_ROPE_SCALING_TYPE_NONE = 0,
    LLAMA_ROPE_SCALING_TYPE_LINEAR = 1,
    LLAMA_ROPE_SCALING_TYPE_YARN = 2,
    LLAMA_ROPE_SCALING_TYPE_MAX_VALUE = 2,
};

// Params structures
struct llama_model_params {
    int n_gpu_layers;
    int split_mode;
    int main_gpu;
    const float * tensor_split;
    const char * vocab_only;
    bool use_mmap;
    bool use_mlock;
    bool check_tensors;
};

struct llama_context_params {
    uint32_t seed;
    uint32_t n_ctx;
    uint32_t n_batch;
    uint32_t n_ubatch;
    uint32_t n_seq_max;
    uint32_t n_threads;
    uint32_t n_threads_batch;
    llama_rope_scaling_type rope_scaling_type;
    float rope_freq_base;
    float rope_freq_scale;
    float yarn_ext_factor;
    float yarn_attn_factor;
    float yarn_beta_fast;
    float yarn_beta_slow;
    uint32_t yarn_orig_ctx;
    float defrag_thold;
    bool logits_all;
    bool embeddings;
    bool offload_kqv;
    bool flash_attn;
    bool no_perf;
};

struct llama_batch {
    int32_t n_tokens;
    llama_token * token;
    float * embd;
    llama_pos * pos;
    int32_t * n_seq_id;
    llama_token ** seq_id;
    int8_t * logits;
    llama_pos all_pos_0;
    llama_pos all_pos_1;
    llama_pos all_seq_id;
};

// C function declarations
extern "C" {
    // Model loading
    struct llama_model * llama_load_model_from_file(const char * path_model, struct llama_model_params params);
    void llama_free_model(struct llama_model * model);
    
    // Context creation
    struct llama_context * llama_new_context_with_model(struct llama_model * model, struct llama_context_params params);
    void llama_free(struct llama_context * ctx);
    
    // Params defaults
    struct llama_model_params llama_model_default_params(void);
    struct llama_context_params llama_context_default_params(void);
    
    // Tokenization
    int32_t llama_tokenize(const struct llama_model * model, const char * text, int32_t text_len, llama_token * tokens, int32_t n_max_tokens, bool add_special, bool parse_special);
    int32_t llama_token_to_piece(const struct llama_model * model, llama_token token, char * buf, int32_t length, int32_t lstrip, bool special);
    
    // Vocabulary info
    int32_t llama_n_vocab(const struct llama_model * model);
    llama_token llama_token_eos(const struct llama_model * model);
    llama_token llama_token_bos(const struct llama_model * model);
    bool llama_token_is_eog(const struct llama_model * model, llama_token token);
    
    // Inference
    int32_t llama_decode(struct llama_context * ctx, struct llama_batch batch);
    float * llama_get_logits(struct llama_context * ctx);
    float * llama_get_logits_ith(struct llama_context * ctx, int32_t i);
    
    // Batch management
    struct llama_batch llama_batch_init(int32_t n_tokens_alloc, int32_t embd, int32_t n_seq_max);
    void llama_batch_free(struct llama_batch batch);
    void llama_batch_clear(struct llama_batch * batch);
    void llama_batch_add(struct llama_batch * batch, llama_token id, llama_pos pos, const int32_t * seq_ids, size_t n_seq_ids, bool logits);
    
    // Getters
    const struct llama_model * llama_get_model(const struct llama_context * ctx);
    uint32_t llama_n_ctx(const struct llama_context * ctx);
    int32_t llama_n_vocab(const struct llama_context * ctx);
}

// MARK: - ggml (minimal)
struct ggml_init_params;
void ggml_time_init(void);
int64_t ggml_time_ms(void);

#endif /* Scribe_Bridging_Header_h */
