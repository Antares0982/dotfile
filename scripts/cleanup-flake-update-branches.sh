#!/usr/bin/env bash
set -euo pipefail

remote="${1:-origin}"
git fetch --prune "$remote"

mapfile -t pending_branches < <(git for-each-ref \
	--sort=-committerdate \
	--format='%(refname:strip=3)' \
	"refs/remotes/${remote}/pending-flake-update/nixpkgs-*" \
	"refs/remotes/${remote}/pending-flake-update/*/nixpkgs-*")

if ((${#pending_branches[@]})); then
	echo "Deleting ${#pending_branches[@]} pending branch(es) on remote '${remote}':"
	printf '  %s\n' "${pending_branches[@]}"
	echo
	git push "$remote" --delete "${pending_branches[@]}"
	echo
fi

mapfile -t hosts < <(git for-each-ref \
	--format='%(refname:strip=3)' \
	"refs/remotes/${remote}/flake-update/*/nixpkgs-*" \
	| cut -d/ -f2 \
	| sort -u)

if ((${#hosts[@]} == 0)); then
	echo "No flake-update branches found on remote '${remote}'."
	exit 0
fi

for host in "${hosts[@]}"; do
	mapfile -t branches < <(git for-each-ref \
		--sort=-committerdate \
		--format='%(refname:strip=3)' \
		"refs/remotes/${remote}/flake-update/${host}/nixpkgs-*")

	echo "Keeping: ${branches[0]}"
	if ((${#branches[@]} > 1)); then
		to_delete=("${branches[@]:1}")
		echo "Deleting ${#to_delete[@]} branch(es) on remote '${remote}':"
		printf '  %s\n' "${to_delete[@]}"
		git push "$remote" --delete "${to_delete[@]}"
	fi
done

echo "Done."
