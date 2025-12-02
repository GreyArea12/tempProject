/*
 * Author: Benedict R. Gaster
 * Module: Advanced Systems Programming
 *
 * Derived from the excellent blog post: https://graphitemaster.github.io/fibers/
 */
#pragma once

struct Context {
  void *rip, *rsp;
  void *rbx, *rbp, *r12, *r13, *r14, *r15;
};

int get_context(struct Context *c);
void set_context(struct Context *c);
void swap_context(struct Context *out, struct Context *in);