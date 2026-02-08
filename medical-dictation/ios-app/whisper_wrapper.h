//
//  whisper_wrapper.h
//  HxDictate
//
//  C wrapper header for whisper.cpp
//

#ifndef whisper_wrapper_h
#define whisper_wrapper_h

#include <stdint.h>
#include <stdbool.h>

// Opaque types
struct whisper_context;
struct whisper_context_params;
struct whisper_full_params;

// Note: whisper_sampling_strategy enum is defined in whisper.h
// We just need to declare it here for the function signatures
enum whisper_sampling_strategy;

// Context Management
struct whisper_context_params * whisper_context_default_params_by_ref_wrapper(void);
void whisper_free_context_params_wrapper(struct whisper_context_params * params);
struct whisper_context * whisper_init_from_file_with_params_wrapper(const char * path_model, struct whisper_context_params * params);
void whisper_free_wrapper(struct whisper_context * ctx);

// Full Transcription
struct whisper_full_params * whisper_full_default_params_by_ref_wrapper(enum whisper_sampling_strategy strategy);
void whisper_free_params_wrapper(struct whisper_full_params * params);

// Parameter Setters
void whisper_full_params_set_n_threads(struct whisper_full_params * params, int n_threads);
void whisper_full_params_set_language(struct whisper_full_params * params, const char * language);
void whisper_full_params_set_translate(struct whisper_full_params * params, bool translate);
void whisper_full_params_set_no_context(struct whisper_full_params * params, bool no_context);
void whisper_full_params_set_single_segment(struct whisper_full_params * params, bool single_segment);
void whisper_full_params_set_print_special(struct whisper_full_params * params, bool print_special);
void whisper_full_params_set_print_progress(struct whisper_full_params * params, bool print_progress);
void whisper_full_params_set_print_realtime(struct whisper_full_params * params, bool print_realtime);
void whisper_full_params_set_print_timestamps(struct whisper_full_params * params, bool print_timestamps);

// Transcription
int whisper_full_wrapper(struct whisper_context * ctx, struct whisper_full_params * params, const float * samples, int n_samples);
int whisper_full_n_segments_wrapper(const struct whisper_context * ctx);
const char * whisper_full_get_segment_text_wrapper(const struct whisper_context * ctx, int i_segment);

#endif /* whisper_wrapper_h */
