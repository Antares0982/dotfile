#!/usr/bin/env bash
set -euo pipefail

remote="${1:-origin}"
cutoff=$(date -d '2 months ago' '+%Y-%m-%d-%H-%M')
refs=$(git ls-remote --tags --refs "$remote")
old_tags=()
local_tags=()

while IFS=$'\t' read -r _ ref; do
	tag=${ref#refs/tags/}
	if [[ $tag =~ ^.+-([0-9]{4})-([0-9]{2})-([0-9]{2})-([0-9]{2})-([0-9]{2})$ ]]; then
		stamp="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]}-${BASH_REMATCH[4]}-${BASH_REMATCH[5]}"
		parsed=$(date -d "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}" '+%Y-%m-%d-%H-%M' 2>/dev/null || true)
		[[ $parsed == "$stamp" && $stamp < $cutoff ]] && old_tags+=("$tag")
	fi
done <<< "$refs"

for tag in "${old_tags[@]}"; do
	git show-ref --verify --quiet "refs/tags/$tag" && local_tags+=("$tag")
done

if ((${#old_tags[@]} == 0)); then
	echo "No tags older than $cutoff on remote '$remote'."
	exit 0
fi

echo "Tags older than $cutoff on remote '$remote':"
printf '  %s\n' "${old_tags[@]}"
echo
read -rp "Delete ${#old_tags[@]} remote tag(s)? [y/N] " confirm
[[ $confirm =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

delete_refs=()
for tag in "${old_tags[@]}"; do
	delete_refs+=(":refs/tags/$tag")
done

git push "$remote" "${delete_refs[@]}"
if ((${#local_tags[@]})); then
	git tag -d "${local_tags[@]}"
fi
echo "Done."
