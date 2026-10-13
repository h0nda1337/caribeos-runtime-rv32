/* Copyright (c) 2026 h0nda1337
 * SPDX-License-Identifier: BSD-2-Clause
 * Preserve the actual native-port byte count; Syllable get_msg_x returns status.
 */
#ifndef CARIBE_SYLLABLE_MESSAGE_IO_H
#define CARIBE_SYLLABLE_MESSAGE_IO_H
#include <atheos/types.h>
#ifdef __cplusplus
extern "C" {
#endif
status_t caribe_get_message(port_id port, uint32 *code, void *buffer,
    int capacity, bigtime_t timeout, size_t *received_size);
#ifdef __cplusplus
}
#endif
#endif
