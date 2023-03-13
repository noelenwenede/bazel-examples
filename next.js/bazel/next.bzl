load("@aspect_rules_js//js:defs.bzl", "js_binary", "js_image_layer", "js_run_binary", "js_run_devserver")
load("@aspect_bazel_lib//lib:run_binary.bzl", "run_binary")
load("@contrib_rules_oci//oci:defs.bzl", "oci_image")
load("@contrib_rules_oci//oci/private:tarball.bzl", "oci_tarball")
load("@aspect_bazel_lib//lib:transitions.bzl", "platform_transition_filegroup")

def next(
        name,
        srcs,
        data,
        next_js_binary,
        next_bin,
        next_build_out = ".next",
        next_export_out = "out",
        **kwargs):
    """Generates Next.js targets build, dev & start targets.

    `{name}`       - a js_run_binary build target that runs `next build`
    `{name}_dev`   - a js_run_devserver binary target that runs `next dev`
    `{name}_start` - a js_run_devserver binary target that runs `next start`

    Use this macro in the BUILD file at the root of a next app where the `next.config.js` file is
    located.

    For example, a target such as

    ```
    load("//bazel:next.bzl", "next")

    next(
        name = "next",
        srcs = [
            "//apps/alpha/pages",
            "//apps/alpha/public",
            "//apps/alpha/styles",
        ],
        data = [
            "//:node_modules/next",
            "//:node_modules/react-dom",
            "//:node_modules/react",
            "//:node_modules/typescript",
            "next.config.js",
            "package.json",
        ],
        next_bin = "../../node_modules/.bin/next",
        next_js_binary = ":next_js_binary",
    )
    ```

    in an `apps/alpha/BUILD.bazel` file where the root `BUILD.bazel` file has
    next linked to `node_modules` and the `next_js_binary`:

    ```
    load("@npm//:defs.bzl", "npm_link_all_packages")
    load("@npm//:next/package_json.bzl", next_bin = "bin")

    npm_link_all_packages(name = "node_modules")

    next_bin.next_binary(
        name = "next_js_binary",
        visibility = ["//visibility:public"],
    )
    ```

    will create the targets:

    ```
    //apps/alpha:next
    //apps/alpha:next_dev
    //apps/alpha:next_start
    ```

    To build the above next app, equivalent to running
    `next build` outside Bazel, run,

    ```
    bazel build //apps/alpha:next
    ```

    To run the development server in watch mode with
    [ibazel](https://github.com/bazelbuild/bazel-watcher), equivalent to running
    `next dev` outside Bazel, run

    ```
    ibazel run //apps/alpha:next_dev
    ```

    To run the production server in watch mode with
    [ibazel](https://github.com/bazelbuild/bazel-watcher), equivalent to running
    `next start` outside Bazel,

    ```
    ibazel run //apps/alpha:next_start
    ```

    To export the above next app, equivalent to running
    `next export` outside Bazel, run,

    ```
    bazel build //apps/alpha:next_export
    ```

    Args:
        name: The name of the build target.

        srcs: Source files to include in build & dev targets.
            Typically these are source files or transpiled source files in Next.js source folders
            such as `pages`, `public` & `styles`.

        data: Data files to include in all targets.
            These are typically npm packages required for the build & configuration files such as
            package.json and next.config.js.

        next_js_binary: The next js_binary. Used for the `build `target.

            Typically this is a js_binary target created using `bin` loaded from the `package_json.bzl`
            file of the npm package.

            See main docstring above for example usage.

        next_bin: The next bin command. Used for the `dev` and `start` targets.

            Typically the path to the next entry point from the current package. For example `./node_modules/.bin/next`,
            if next is linked to the current package, or a relative path such as `../node_modules/.bin/next`, if next is
            linked in the parent package.

            See main docstring above for example usage.

        next_build_out: The `next build` output directory. Defaults to `.next` which is the Next.js default output directory for the `build` command.

        next_export_out: The `next export` output directory. Defaults to `out` which is the Next.js default output directory for the `export` command.

        **kwargs: Other attributes passed to all targets such as `tags`.
    """

    tags = kwargs.pop("tags", [])

    # `next build` creates an optimized bundle of the application
    # https://nextjs.org/docs/api-reference/cli#build
    js_run_binary(
        name = name,
        tool = next_js_binary,
        args = ["build"],
        srcs = srcs + data,
        out_dirs = [next_build_out],
        chdir = native.package_name(),
        tags = tags,
        **kwargs
    )

    js_run_binary(
        name = "build",
        tool = next_js_binary,
        args = ["build"],
        srcs = srcs + data,
        out_dirs = [next_build_out],
        chdir = native.package_name(),
        tags = tags,
        execution_requirements = {
            "no-sandbox": "1",
        },
        **kwargs
    )

    # `next dev` runs the application in development mode
    # https://nextjs.org/docs/api-reference/cli#development
    js_run_devserver(
        name = "{}_dev".format(name),
        command = next_bin,
        args = ["dev"],
        data = srcs + data,
        chdir = native.package_name(),
        tags = tags,
        **kwargs
    )

    # `next start` runs the application in production mode
    # https://nextjs.org/docs/api-reference/cli#production
    js_run_devserver(
        name = "{}_start".format(name),
        command = next_bin,
        args = ["start"],
        data = data + [name],
        chdir = native.package_name(),
        tags = tags,
        **kwargs
    )

    # `next export` runs the application in production mode
    # https://nextjs.org/docs/api-reference/cli#production
    js_run_binary(
        name = "{}_export".format(name),
        tool = next_js_binary,
        args = ["export"],
        srcs = data + [name],
        out_dirs = [next_export_out],
        chdir = native.package_name(),
        # Tagged as "manual" since this `next export` writes back to the `.next` directory which causes issues with
        # trying to write to an input. See https://github.com/vercel/next.js/issues/43344.
        # TODO: fix in Next.js (https://github.com/vercel/next.js/issues/43344) or find work-around.
        tags = tags + ["manual"],
        **kwargs
    )

    native.sh_binary(
        name = "generate_dist_bin",
        srcs = ["generate_dist.sh"],
    )

    run_binary(
        name = "generate_dist",
        srcs = [
            ":build",
            "//{}/public".format(native.package_name()),
        ],
        outs = [
            # "dist/package.json",
            "dist/server.js",
        ],
        args = [
            "$(location :build)",
            "$(location :build)/../public",
            "$(@D)/dist",
        ],
        out_dirs = [
            "dist/.next",
            "dist/public",
        ],
        tool = "generate_dist_bin",
    )

    js_binary(
        name = "bin",
        chdir = "{}/dist".format(native.package_name()),
        copy_data_to_bin = False,
        data = [":generate_dist"] + [
            "//:node_modules/next",
            "//:node_modules/react",
            "//:node_modules/react-dom",
        ],
        entry_point = "dist/server.js",
    )

    native.platform(
        name = "amd64_linux",
        constraint_values = [
            "@platforms//os:linux",
            "@platforms//cpu:x86_64",
        ],
    )

    native.platform(
        name = "arm64_linux",
        constraint_values = [
            "@platforms//os:linux",
            "@platforms//cpu:arm64",
        ],
    )

    js_image_layer(
        name = "layers",
        binary = ":bin",
        platform = select({
            "@platforms//cpu:arm64": "linux_arm64",
            "@platforms//cpu:x86_64": "linux_amd64",
        }),
        root = "/app",
    )

    platform_transition_filegroup(
        name = "transitioned_layers",
        srcs = [":layers"],
        target_platform = select({
            "@platforms//cpu:arm64": "linux_arm64",
            "@platforms//cpu:x86_64": "linux_amd64",
        }),
    )

    oci_image(
        name = "{}_image".format(name),
        cmd = ["/app/apps/alpha/bin"],
        entrypoint = ["bash"],
        tars = [":transitioned_layers"],
        base = "@debian_amd64//:image",
        architecture = select({
            "@platforms//cpu:arm64": "arm64",
            "@platforms//cpu:x86_64": "amd64",
        }),
        workdir = "/app/{}/bin.runfiles/__main__".format(native.package_name()),
    )

    oci_tarball(
        name = "{}_tarball".format(name),
        image = "{}_image".format(name),
        repotags = ["nextjs/js:latest"],
    )
