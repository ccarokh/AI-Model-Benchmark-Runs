#!/bin/bash
# Round 8 builds (26.10.): PR #25051 at ecfee2ece6 (24.10., host-memory all-reduce with a host-thread
# bridge for mixed vendors) and its merge base with master, each in its own prefix.
# (The first run of 26.10. took the merge base against FETCH_HEAD, which held the PR head: its "1026base"
# was the PR again. The base is built as 1026master.)
set -e
cd /opt/src/llama.cpp
git fetch -q origin pull/25051/head:pr-25051-1026 +master:refs/remotes/origin/master
H=ecfee2ece6
[ "$(git rev-parse --short=10 pr-25051-1026)" = $H ] || echo "Hinweis: PR-Kopf ist inzwischen $(git rev-parse --short=10 pr-25051-1026), gebaut wird $H"
BASE=$(git merge-base $H origin/master)
bau(){  # tag commit
  local W=/opt/src/llama.cpp-vktp-$1 P=/opt/llama-cpp-vktp-$1
  [ -d $W ] || git worktree add -q --detach $W $2
  ( cd $W && git log -1 --format="$1: %h %ad %s" --date=short
    cmake -B build -DCMAKE_INSTALL_PREFIX=$P -DGGML_VULKAN=ON -DLLAMA_CURL=OFF -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_SERVER=ON -DCMAKE_BUILD_TYPE=Release > /root/eval/vktp_$1.cmake.log 2>&1
    cmake --build build -j12 > /root/eval/vktp_$1.build.log 2>&1
    cmake --install build > /dev/null && ls $P/bin/llama-bench )
}
bau 1026 $H
bau 1026master $BASE
echo FERTIG_BAU
