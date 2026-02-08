//
//  Scribe-Bridging-Header.h
//  HxDictate
//
//  Bridging header - imports whisper and llama wrappers
//

#ifndef Scribe_Bridging_Header_h
#define Scribe_Bridging_Header_h

// Import whisper.h first to get the enum definitions
#import <whisper.h>

// Whisper wrapper
#import "whisper_wrapper.h"

// Import llama.h for types
#import <llama.h>

// Llama wrapper
#import "llama_wrapper.h"

#endif /* Scribe_Bridging_Header_h */
