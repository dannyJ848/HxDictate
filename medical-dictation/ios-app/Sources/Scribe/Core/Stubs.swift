// Stub implementations for C functions
// These allow the app to build without linking the actual C++ libraries
// For testing UI only - replace with real implementations for production

import Foundation

// MARK: - whisper.cpp stubs
struct whisper_context {}
struct whisper_full_params {}
struct whisper_context_params {
    var use_gpu: Int32 = 0
    var flash_attn: Int32 = 0
}

func whisper_context_default_params() -> whisper_context_params {
    return whisper_context_params()
}

func whisper_init_from_file_with_params(_ path: UnsafePointer<CChar>, _ params: whisper_context_params) -> OpaquePointer? {
    print("STUB: whisper_init_from_file_with_params called with path: \(String(cString: path))")
    return OpaquePointer(Unmanaged<whisper_context>.passRetained(whisper_context()).toOpaque())
}

func whisper_free(_ ctx: OpaquePointer?) {
    print("STUB: whisper_free called")
}

func whisper_full_default_params(_ strategy: Int32) -> whisper_full_params {
    return whisper_full_params()
}

func whisper_full(_ ctx: OpaquePointer?, _ params: whisper_full_params, _ samples: UnsafePointer<Float>?, _ n_samples: Int32) -> Int32 {
    return 0
}

func whisper_full_n_segments(_ ctx: OpaquePointer?) -> Int32 {
    return 0
}

func whisper_full_get_segment_text(_ ctx: OpaquePointer?, _ segment: Int32) -> UnsafePointer<CChar>? {
    return nil
}

// MARK: - llama.cpp stubs
typealias llama_token = Int32
typealias llama_pos = Int32
struct llama_model {}
struct llama_context {}
struct llama_batch {
    var n_tokens: Int32 = 0
    var token: UnsafeMutablePointer<llama_token>?
    var pos: UnsafeMutablePointer<llama_pos>?
    var logits: UnsafeMutablePointer<Int8>?
}

struct llama_model_params {
    var n_gpu_layers: Int32 = 0
    var use_mmap: Int32 = 0
    var use_mlock: Int32 = 0
}

struct llama_context_params {
    var seed: UInt32 = 0
    var n_ctx: UInt32 = 0
    var n_batch: UInt32 = 0
    var n_threads: UInt32 = 0
    var n_threads_batch: UInt32 = 0
    var logits_all: Int32 = 0
    var embeddings: Int32 = 0
    var flash_attn: Int32 = 0
}

func llama_model_default_params() -> llama_model_params {
    return llama_model_params()
}

func llama_context_default_params() -> llama_context_params {
    return llama_context_params()
}

func llama_load_model_from_file(_ path: UnsafePointer<CChar>, _ params: llama_model_params) -> OpaquePointer? {
    print("STUB: llama_load_model_from_file called with path: \(String(cString: path))")
    return OpaquePointer(Unmanaged<llama_model>.passRetained(llama_model()).toOpaque())
}

func llama_free_model(_ model: OpaquePointer?) {
    print("STUB: llama_free_model called")
}

func llama_new_context_with_model(_ model: OpaquePointer?, _ params: llama_context_params) -> OpaquePointer? {
    print("STUB: llama_new_context_with_model called")
    return OpaquePointer(Unmanaged<llama_context>.passRetained(llama_context()).toOpaque())
}

func llama_free(_ ctx: OpaquePointer?) {
    print("STUB: llama_free called")
}

func llama_tokenize(_ model: OpaquePointer?, _ text: UnsafePointer<CChar>, _ text_len: Int32, _ tokens: UnsafeMutablePointer<llama_token>?, _ n_max_tokens: Int32, _ add_special: Int32, _ parse_special: Int32) -> Int32 {
    return 0
}

func llama_token_to_piece(_ model: OpaquePointer?, _ token: llama_token, _ buf: UnsafeMutablePointer<CChar>, _ length: Int32, _ lstrip: Int32, _ special: Int32) -> Int32 {
    return 0
}

func llama_decode(_ ctx: OpaquePointer?, _ batch: llama_batch) -> Int32 {
    return 0
}

func llama_get_logits(_ ctx: OpaquePointer?) -> UnsafeMutablePointer<Float>? {
    return nil
}

func llama_get_logits_ith(_ ctx: OpaquePointer?, _ i: Int32) -> UnsafeMutablePointer<Float>? {
    return nil
}

func llama_token_eos(_ model: OpaquePointer?) -> llama_token {
    return 0
}

func llama_get_model(_ ctx: OpaquePointer?) -> OpaquePointer? {
    return nil
}

func llama_n_vocab(_ model: OpaquePointer?) -> Int32 {
    return 0
}

func llama_n_ctx(_ ctx: OpaquePointer?) -> UInt32 {
    return 0
}

func llama_batch_init(_ n_tokens_alloc: Int32, _ embd: Int32, _ n_seq_max: Int32) -> llama_batch {
    return llama_batch()
}

func llama_batch_free(_ batch: llama_batch) {
}
