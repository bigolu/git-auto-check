#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
	if [[ $1 == 'install' ]]; then
		git config hook.auto-check.event 'pre-push'
		shift
		git config hook.auto-check.command "git-auto-check ${*@Q}"
		exit
	fi

	echo '[git-auto-check] Checking commits...'

	local ref_updates
	readarray -t ref_updates
	if (( ${#ref_updates[@]} != 1 )); then
		exit
	fi

	local _local_ref local_sha _remote_ref remote_sha
	read -r _local_ref local_sha _remote_ref remote_sha <<<"${ref_updates[0]}"
	# All zeros means we are deleting a ref.
	if [[ $local_sha =~ ^0+$ ]]; then
		exit
	fi

	# All zeros means we are creating a new ref.
	if [[ $remote_sha =~ ^0+$ ]]; then
		local -a remote_branch_shas
		readarray -t remote_branch_shas <<<"$(git rev-parse --remotes)"

		merge_base="$(git merge-base "$local_sha" "${remote_branch_shas[@]}")"
		if [[ -z $merge_base ]]; then
			exit
		fi
	else
		merge_base="$remote_sha"
	fi
	if [[ $merge_base == "$local_sha" ]]; then
		exit
	fi

	# Stop the sequence editor from launching by setting it to a no-op.
	git -c sequence.editor=: rebase --interactive --exec "${*@Q}" "$merge_base"
}

main "$@"
