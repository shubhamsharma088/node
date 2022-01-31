# Copyright 2021 the V8 project authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

FlagInfo = provider(fields = ["value"])

def _options_impl(ctx):
    return FlagInfo(value = ctx.build_setting_value)

_create_option_flag = rule(
    implementation = _options_impl,
    build_setting = config.bool(flag = True),
)

_create_option_string = rule(
    implementation = _options_impl,
    build_setting = config.string(flag = True),
)

_create_option_int = rule(
    implementation = _options_impl,
    build_setting = config.int(flag = True),
)

def v8_flag(name, default = False):
    _create_option_flag(name = name, build_setting_default = default)
    native.config_setting(name = "is_" + name, flag_values = {name: "True"})
    native.config_setting(name = "is_not_" + name, flag_values = {name: "False"})

def v8_string(name, default = ""):
    _create_option_string(name = name, build_setting_default = default)

def v8_int(name, default = 0):
    _create_option_int(name = name, build_setting_default = default)

def _custom_config_impl(ctx):
    defs = []
    defs.append("V8_TYPED_ARRAY_MAX_SIZE_IN_HEAP=" +
                str(ctx.attr._v8_typed_array_max_size_in_heap[FlagInfo].value))
    context = cc_common.create_compilation_context(defines = depset(defs))
    return [CcInfo(compilation_context = context)]

v8_custom_config = rule(
    implementation = _custom_config_impl,
    attrs = {
        "_v8_typed_array_max_size_in_heap": attr.label(default = ":v8_typed_array_max_size_in_heap"),
    },
)

def _config_impl(ctx):
    hdrs = []

    # Add headers
    for h in ctx.attr.hdrs:
        hdrs += h[DefaultInfo].files.to_list()
    defs = []

    # Add conditional_defines
    for f, d in ctx.attr.conditional_defines.items():
        if f[FlagInfo].value:
            defs.append(d)

    # Add defines
    for d in ctx.attr.defines:
        defs.append(d)
    context = cc_common.create_compilation_context(
        defines = depset(
            defs,
            transitive = [dep[CcInfo].compilation_context.defines for dep in ctx.attr.deps],
        ),
        headers = depset(
            hdrs,
            transitive = [dep[CcInfo].compilation_context.headers for dep in ctx.attr.deps],
        ),
    )
    return [CcInfo(compilation_context = context)]

v8_config = rule(
    implementation = _config_impl,
    attrs = {
        "conditional_defines": attr.label_keyed_string_dict(),
        "defines": attr.string_list(),
        "deps": attr.label_list(),
        "hdrs": attr.label_list(allow_files = True),
    },
)

def _default_args():
    return struct(
        deps = [":define_flags"],
        copts = [
            "-fPIC",
            "-Werror",
            "-Wextra",
            "-Wno-bitwise-instead-of-logical",
            "-Wno-builtin-assume-aligned-alignment",
            "-Wno-unused-parameter",
            "-Wno-implicit-int-float-conversion",
            "-Wno-deprecated-copy",
            "-Wno-non-virtual-dtor",
            "-std=c++17",
            "-isystem .",
        ],
        includes = ["include"],
        linkopts = [
            "-pthread",
        ] + select({
            "@config//:is_macos": [],
            "//conditions:default": ["-Wl,--no-as-needed -ldl"],
        }) + select({
            ":should_add_rdynamic": ["-rdynamic"],
            "//conditions:default": [],
        }),
    )

ENABLE_I18N_SUPPORT_DEFINES = [
    "-DV8_INTL_SUPPORT",
    "-DICU_UTIL_DATA_IMPL=ICU_UTIL_DATA_STATIC",
    # src/regexp/regexp-compiler-tonode.cc uses an unsafe ICU method and
    # access a character implicitly.
    "-DUNISTR_FROM_CHAR_EXPLICIT=",
]

def _should_emit_noicu_and_icu(noicu_srcs, noicu_deps, icu_srcs, icu_deps):
    return noicu_srcs != [] or noicu_deps != [] or icu_srcs != [] or icu_deps != []

# buildifier: disable=function-docstring
def v8_binary(
        name,
        srcs,
        deps = [],
        includes = [],
        copts = [],
        linkopts = [],
        noicu_srcs = [],
        noicu_deps = [],
        icu_srcs = [],
        icu_deps = [],
        **kwargs):
    default = _default_args()
    if _should_emit_noicu_and_icu(noicu_srcs, noicu_deps, icu_srcs, icu_deps):
        native.cc_binary(
            name = "noicu/" + name,
            srcs = srcs + noicu_srcs,
            deps = deps + noicu_deps + default.deps,
            includes = includes + default.includes,
            copts = copts + default.copts,
            linkopts = linkopts + default.linkopts,
            **kwargs
        )
        native.cc_binary(
            name = "icu/" + name,
            srcs = srcs + icu_srcs,
            deps = deps + icu_deps + default.deps,
            includes = includes + default.includes,
            copts = copts + default.copts + ENABLE_I18N_SUPPORT_DEFINES,
            linkopts = linkopts + default.linkopts,
            **kwargs
        )
    else:
        native.cc_binary(
            name = name,
            srcs = srcs,
            deps = deps + default.deps,
            includes = includes + default.includes,
            copts = copts + default.copts,
            linkopts = linkopts + default.linkopts,
            **kwargs
        )

# buildifier: disable=function-docstring
def v8_library(
        name,
        srcs,
        deps = [],
        includes = [],
        copts = [],
        linkopts = [],
        noicu_srcs = [],
        noicu_deps = [],
        icu_srcs = [],
        icu_deps = [],
        **kwargs):
    default = _default_args()
    if _should_emit_noicu_and_icu(noicu_srcs, noicu_deps, icu_srcs, icu_deps):
        native.cc_library(
            name = "noicu/" + name,
            srcs = srcs + noicu_srcs,
            deps = deps + noicu_deps + default.deps,
            includes = includes + default.includes,
            copts = copts + default.copts,
            linkopts = linkopts + default.linkopts,
            alwayslink = 1,
            **kwargs
        )
        native.cc_library(
            name = "icu/" + name,
            srcs = srcs + icu_srcs,
            deps = deps + icu_deps + default.deps,
            includes = includes + default.includes,
            copts = copts + default.copts + ENABLE_I18N_SUPPORT_DEFINES,
            linkopts = linkopts + default.linkopts,
            alwayslink = 1,
            **kwargs
        )
    else:
        native.cc_library(
            name = name,
            srcs = srcs,
            deps = deps + default.deps,
            includes = includes + default.includes,
            copts = copts + default.copts,
            linkopts = linkopts + default.linkopts,
            alwayslink = 1,
            **kwargs
        )

def _torque_impl(ctx):
    v8root = "."
    prefix = ctx.attr.prefix

    # Arguments
    args = []
    args += ctx.attr.args
    args.append("-o")
    args.append(ctx.bin_dir.path + "/" + v8root + "/" + ctx.attr.prefix + "/torque-generated")
    args.append("-strip-v8-root")
    args.append("-v8-root")
    args.append(v8root)

    # Sources
    args += [f.path for f in ctx.files.srcs]

    # Generate/declare output files
    outs = []
    for src in ctx.files.srcs:
        root, period, ext = src.path.rpartition(".")

        # Strip v8root
        if root[:len(v8root)] == v8root:
            root = root[len(v8root):]
        file = ctx.attr.prefix + "/torque-generated/" + root
        outs.append(ctx.actions.declare_file(file + "-tq-csa.cc"))
        outs.append(ctx.actions.declare_file(file + "-tq-csa.h"))
        outs.append(ctx.actions.declare_file(file + "-tq-inl.inc"))
        outs.append(ctx.actions.declare_file(file + "-tq.inc"))
        outs.append(ctx.actions.declare_file(file + "-tq.cc"))
    outs += [ctx.actions.declare_file(ctx.attr.prefix + "/torque-generated/" + f) for f in ctx.attr.extras]
    ctx.actions.run(
        outputs = outs,
        inputs = ctx.files.srcs,
        arguments = args,
        executable = ctx.executable.tool,
        mnemonic = "GenTorque",
        progress_message = "Generating Torque files",
    )
    return [DefaultInfo(files = depset(outs))]

_v8_torque = rule(
    implementation = _torque_impl,
    # cfg = v8_target_cpu_transition,
    attrs = {
        "prefix": attr.string(mandatory = True),
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "extras": attr.string_list(),
        "tool": attr.label(
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
        "args": attr.string_list(),
        "v8root": attr.label(default = ":v8_root"),
    },
)

def v8_torque(name, noicu_srcs, icu_srcs, args, extras):
    _v8_torque(
        name = "noicu/" + name,
        prefix = "noicu",
        srcs = noicu_srcs,
        args = args,
        extras = extras,
        tool = select({
            "@config//:v8_target_is_32_bits": ":torque_non_pointer_compression",
            "//conditions:default": ":torque",
        }),
    )
    _v8_torque(
        name = "icu/" + name,
        prefix = "icu",
        srcs = icu_srcs,
        args = args,
        extras = extras,
        tool = select({
            "@config//:v8_target_is_32_bits": ":torque_non_pointer_compression",
            "//conditions:default": ":torque",
        }),
    )

def _mksnapshot(ctx):
    outs = [
        ctx.actions.declare_file(ctx.attr.prefix + "/snapshot.cc"),
        ctx.actions.declare_file(ctx.attr.prefix + "/embedded.S"),
    ]
    ctx.actions.run(
        outputs = outs,
        inputs = [],
        arguments = [
            "--embedded_variant=Default",
            "--startup_src",
            outs[0].path,
            "--embedded_src",
            outs[1].path,
        ] + ctx.attr.args,
        executable = ctx.executable.tool,
        progress_message = "Running mksnapshot",
    )
    return [DefaultInfo(files = depset(outs))]

_v8_mksnapshot = rule(
    implementation = _mksnapshot,
    attrs = {
        "args": attr.string_list(),
        "tool": attr.label(
            mandatory = True,
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
        "prefix": attr.string(mandatory = True),
    },
)

def v8_mksnapshot(name, args):
    _v8_mksnapshot(
        name = "noicu/" + name,
        args = args,
        prefix = "noicu",
        tool = ":noicu/mksnapshot",
    )
    _v8_mksnapshot(
        name = "icu/" + name,
        args = args,
        prefix = "icu",
        tool = ":icu/mksnapshot",
    )

def _quote(val):
    if val[0] == '"' and val[-1] == '"':
        fail("String", val, "already quoted")
    return '"' + val + '"'

def _kv_bool_pair(k, v):
    return _quote(k) + ": " + v

def _json(kv_pairs):
    content = "{"
    for (k, v) in kv_pairs[:-1]:
        content += _kv_bool_pair(k, v) + ", "
    (k, v) = kv_pairs[-1]
    content += _kv_bool_pair(k, v)
    content += "}\n"
    return content

def build_config_content(cpu, icu):
    return _json([
        ("current_cpu", cpu),
        ("dcheck_always_on", "false"),
        ("is_android", "false"),
        ("is_asan", "false"),
        ("is_cfi", "false"),
        ("is_clang", "true"),
        ("is_component_build", "false"),
        ("is_debug", "false"),
        ("is_full_debug", "false"),
        ("is_gcov_coverage", "false"),
        ("is_msan", "false"),
        ("is_tsan", "false"),
        ("is_ubsan_vptr", "false"),
        ("target_cpu", cpu),
        ("v8_current_cpu", cpu),
        ("v8_dict_property_const_tracking", "false"),
        ("v8_enable_atomic_marking_state", "false"),
        ("v8_enable_atomic_object_field_writes", "false"),
        ("v8_enable_concurrent_marking", "false"),
        ("v8_enable_i18n_support", icu),
        ("v8_enable_verify_predictable", "false"),
        ("v8_enable_verify_csa", "false"),
        ("v8_enable_lite_mode", "false"),
        ("v8_enable_runtime_call_stats", "false"),
        ("v8_enable_pointer_compression", "true"),
        ("v8_enable_pointer_compression_shared_cage", "false"),
        ("v8_enable_third_party_heap", "false"),
        ("v8_enable_webassembly", "false"),
        ("v8_control_flow_integrity", "false"),
        ("v8_enable_single_generation", "false"),
        ("v8_enable_virtual_memory_cage", "false"),
        ("v8_target_cpu", cpu),
    ])

# TODO(victorgomes): Create a rule (instead of a macro), that can
# dynamically populate the build config.
def v8_build_config(name):
    cpu = _quote("x64")
    native.genrule(
        name = "noicu/" + name,
        outs = ["noicu/" + name + ".json"],
        cmd = "echo '" + build_config_content(cpu, "false") + "' > \"$@\"",
    )
    native.genrule(
        name = "icu/" + name,
        outs = ["icu/" + name + ".json"],
        cmd = "echo '" + build_config_content(cpu, "true") + "' > \"$@\"",
    )