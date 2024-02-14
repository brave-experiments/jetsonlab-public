# Note:   Logic for editing a model config file for JetsonLab experiments.
#         This is invoked by the scripts/run_{mlc,llamacpp}.sh for automated execution.
# Author: Stefanos Laskaridis (stefanos@brave.com)

import argparse
import platform
import subprocess
import sys

from utils.logging import Logger

NUMBER_REGEX = "[0-9]+(\\.[0-9]*)?"
sed_cmd = "sed -r"
if platform.system() == "Darwin":
    sed_cmd = "gsed -E"


def parse_model_args(args):
    model_args = {
        "max_gen_len": args.max_gen_len,
        "max_context_size": args.max_context_size,
        "input_token_batching": vars(args).get("input_token_batching", None),
        "temperature": args.temperature,
        "top_p": vars(args).get("top_p", None),
        "top_k": args.top_k,
        "repeat_penalty": args.repeat_penalty,
    }

    return model_args


def edit_llamacpp_config(model_args, model_config_path):
    for model_arg, value in model_args.items():
        if value is not None:
            if model_arg == "max_context_size":
                src_regex = f"(-c ){NUMBER_REGEX}"
                dst_regex = f"\\1{value}"
            elif model_arg == "max_gen_len":
                src_regex = f"(-n ){NUMBER_REGEX}"
                dst_regex = f"\\1{value}"
            elif model_arg == "input_token_batching":
                src_regex = f"(-b ){NUMBER_REGEX}"
                dst_regex = f"\\1{value}"
            elif model_arg == "temperature":
                src_regex = f"(--temp ){NUMBER_REGEX}"
                dst_regex = f"\\1{value}"
            elif model_arg == "top_p":
                src_regex = f"(--top-p ){NUMBER_REGEX}"
                dst_regex = f"\\1{value}"
            elif model_arg == "top_k":
                src_regex = f"(--top-k ){NUMBER_REGEX}"
                dst_regex = f"\\1{value}"
            elif model_arg == "repeat_penalty":
                src_regex = f"(--repeat-penalty ){NUMBER_REGEX}"
                dst_regex = f"\\1{value}"
            else:
                Logger.get().info(
                    f"Invalid model arg {model_arg}, omitting ...")
                continue
        subprocess.run(
            f"{sed_cmd} -i 's/{src_regex}/{dst_regex}/' {model_config_path}",
            shell=True,
            check=True,
            capture_output=True,
        )


def edit_mlc_config(model_args, model_config_path):
    for model_arg, value in model_args.items():
        if value is not None:
            if model_arg == "max_context_size":
                src_regex = f'(\\"sliding_window\\": | \\"max_window_size\\": ){NUMBER_REGEX}(,)?'
                dst_regex = f"\\1{value}\\3"
            elif model_arg == "repeat_penalty":
                src_regex = f'(\\"repetition_penalty\\": ){NUMBER_REGEX}(,)?'
                dst_regex = f"\\1{value}\\3"
            elif model_arg in ["max_gen_len", "temperature", "top_p"]:
                src_regex = f'\\"{model_arg}\\": {NUMBER_REGEX}(,)?'
                dst_regex = f'\\"{model_arg}\\": {value}\\2'
            else:
                Logger.get().info(
                    f"Invalid model arg {model_arg}, omitting ...")
                continue
            subprocess.run(
                f"{sed_cmd} -i 's/{src_regex}/{dst_regex}/' {model_config_path}",
                shell=True,
                check=True,
                capture_output=True,
            )


def parse_args(args):
    parser = argparse.ArgumentParser(description="Edit model config files")
    parser.add_argument(
        "--app",
        type=str,
        choices=["LlamaCpp", "MLCChat"],
        help="The app to edit the config for",
    )
    parser.add_argument(
        "--model-config-path", type=str, help="The path to the model config file"
    )
    parser.add_argument("--logfile", type=str, help="The path to the log file")
    parser.add_argument(
        "--loglevel",
        type=str,
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        default="INFO",
        help="The log level",
    )

    parser.add_argument(
        "--max-gen-len", type=int, help="Maximum length of the generated response."
    )
    parser.add_argument(
        "--max-context-size", type=int, help="Maximum length of the context."
    )
    parser.add_argument(
        "--input-token-batching",
        required=False,
        type=int,
        help="Batch size for generation (applicable only to llama).",
    )

    # Generation specific arguments
    parser.add_argument("--temperature", type=float,
                        help="Temperature for sampling.")
    parser.add_argument(
        "--top-p", required=False, type=float, help="Top-p for sampling."
    )
    parser.add_argument("--top-k", type=int, help="Top-k for sampling.")
    parser.add_argument(
        "--repeat-penalty", type=float, help="Repeat penalty for sampling."
    )

    args = parser.parse_args(args)
    return args


def main(args):
    model_args = parse_model_args(args)
    Logger.get().info(f"Editing {args.app} config ...")
    if args.app == "LlamaCpp":
        edit_llamacpp_config(model_args, args.model_config_path)
    elif args.app == "MLCChat":
        edit_mlc_config(model_args, args.model_config_path)


if __name__ == "__main__":
    args = parse_args(sys.argv[1:])
    Logger.setup_logging(
        loglevel=args.loglevel,
        logfile=args.logfile,
    )
    main(args)
