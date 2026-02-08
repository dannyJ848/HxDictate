//
//  whisper_wrapper.c
//  HxDictate
//
//  C wrapper to simplify Swift interop with whisper.cpp
//

#include "include/whisper_wrapper.h"
#include "whisper.h"

// MARK: - Context Management

struct whisper_context_params * whisper_context_default_params_by_ref_wrapper(void) {
    return whisper_context_default_params_by_ref();
}

void whisper_free_context_params_wrapper(struct whisper_context_params * params) {
    whisper_free_context_params(params);
}

struct whisper_context * whisper_init_from_file_with_params_wrapper(const char * path_model, struct whisper_context_params * params) {
    return whisper_init_from_file_with_params(path_model, *params);
}

void whisper_free_wrapper(struct whisper_context * ctx) {
    whisper_free(ctx);
}

// MARK: - Full Transcription

struct whisper_full_params * whisper_full_default_params_by_ref_wrapper(enum whisper_sampling_strategy strategy) {
    return whisper_full_default_params_by_ref(strategy);
}

void whisper_free_params_wrapper(struct whisper_full_params * params) {
    whisper_free_params(params);
}

// MARK: - Parameter Setters

void whisper_full_params_set_n_threads(struct whisper_full_params * params, int n_threads) {
    if (params) params->n_threads = n_threads;
}

void whisper_full_params_set_language(struct whisper_full_params * params, const char * language) {
    if (params) params->language = language;
}

void whisper_full_params_set_translate(struct whisper_full_params * params, bool translate) {
    if (params) params->translate = translate;
}

void whisper_full_params_set_no_context(struct whisper_full_params * params, bool no_context) {
    if (params) params->no_context = no_context;
}

void whisper_full_params_set_single_segment(struct whisper_full_params * params, bool single_segment) {
    if (params) params->single_segment = single_segment;
}

void whisper_full_params_set_print_special(struct whisper_full_params * params, bool print_special) {
    if (params) params->print_special = print_special;
}

void whisper_full_params_set_print_progress(struct whisper_full_params * params, bool print_progress) {
    if (params) params->print_progress = print_progress;
}

void whisper_full_params_set_print_realtime(struct whisper_full_params * params, bool print_realtime) {
    if (params) params->print_realtime = print_realtime;
}

void whisper_full_params_set_print_timestamps(struct whisper_full_params * params, bool print_timestamps) {
    if (params) params->print_timestamps = print_timestamps;
}

// MARK: - Transcription

int whisper_full_wrapper(struct whisper_context * ctx, struct whisper_full_params * params, const float * samples, int n_samples) {
    if (!ctx || !params) return -1;
    return whisper_full(ctx, *params, samples, n_samples);
}

int whisper_full_n_segments_wrapper(const struct whisper_context * ctx) {
    return whisper_full_n_segments(ctx);
}

const char * whisper_full_get_segment_text_wrapper(const struct whisper_context * ctx, int i_segment) {
    return whisper_full_get_segment_text(ctx, i_segment);
}
