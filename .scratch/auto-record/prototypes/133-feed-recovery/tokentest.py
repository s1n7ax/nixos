#!/usr/bin/env python3
"""Does a restore token survive a restart of the program?

    python tokentest.py [--no-token] [--cache PATH] [--repeat N]

One portal handshake per repeat, in a process that exits afterwards - which is
the only way to prove the token outlives the process rather than the object.
Prints whether a token went in, whether one came back, whether it is the same
string, and how long the handshake took. A handshake that needs the picker
takes as long as the human does; one that restores takes milliseconds, so the
timing alone says which happened.
"""

import argparse
import pathlib
import sys

import recover
from recover import Screencast, log


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=str(pathlib.Path.home() / ".cache"
                                           / "proto133-restore-token"))
    ap.add_argument("--no-token", action="store_true")
    ap.add_argument("--repeat", type=int, default=1)
    args = ap.parse_args()

    cache = pathlib.Path(args.cache)
    for i in range(args.repeat):
        before = cache.read_text().strip() if cache.exists() else None
        cast = Screencast(token_cache=cache, use_token=not args.no_token)
        after = cache.read_text().strip() if cache.exists() else None
        log(
            f"run {i + 1}: token_in={(before or 'NONE')[:8]} "
            f"token_out={(cast.token_out or 'NONE')[:8]} "
            f"rotated={'yes' if before and after and before != after else 'no'} "
            f"handshake={cast.handshake_s * 1000:.0f}ms "
            f"node={cast.node} fd={cast.fd}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
