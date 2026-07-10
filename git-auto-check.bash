#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s nullglob
shopt -s inherit_errexit

function main {
	if [[ ${GIT_AUTO_CHECK_DEBUG:-} == 'true' ]]; then
		set -o xtrace
	fi

	case "$1" in
		'install')
			git config hook.auto-check.event 'pre-push'
			shift
			git config hook.auto-check.command "git-auto-check $# ${*@Q}"
			exit
			;;
		'cache')
			"$1_$2"
			exit
			;;
		'in-rebase')
			shift

			local is_cached
			is_cached="$(cache_has "$@")"
			if [[ $is_cached == 'true' ]]; then
				log "Command \`$*\` has already passed for this commit, skipping."
				exit
			fi

			if "$@"; then
				cache_add "$@"
			else
				log "Command failed, run \`git-auto-check cache add\` to mark the check as passed."
				exit 1
			fi
			;;
	esac

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
	local merge_base=''
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

	local -a check_command=("${@:2:$1}")
	local commit_count
	commit_count="$(git rev-list --count "$merge_base".."$local_sha")"
	log 'Checking commits...'
	if ((commit_count == 1)); then
		if "${check_command[@]}"; then
			cache_add "${check_command[@]}"
		else
			exit 1
		fi
	else
		set_command "${check_command[@]}"
		# Stop the sequence editor from launching by setting it to a no-op.
		git -c sequence.editor=: rebase --interactive --exec "git-auto-check in-rebase ${check_command[*]@Q}" "$merge_base"
	fi
}

function get_command {
	local git_directory
	git_directory="$(git rev-parse --absolute-git-dir)"
	echo "$(<"$git_directory/git-auto-check/command.txt")"
}

function set_command {
	local command_filename
	command_filename="$(get_command_as_filename "$@")"

	local directory
	directory="$(git rev-parse --absolute-git-dir)/git-auto-check"

	mkdir --parents "$directory"
	echo "$command_filename" >"$directory/command.txt"
}

function cache_get_path {
	local git_directory
	git_directory="$(git rev-parse --absolute-git-dir)"
	echo "$git_directory/git-auto-check/cache"
}

function cache_clear {
	local cache
	cache="$(cache_get_path)"
	rm -rf "$cache"
}

function cache_add {
	if (($# == 0)); then
		local command_filename
		command_filename="$(get_command)"
	else
		local command_filename
		command_filename="$(get_command_as_filename "$@")"
	fi

	local commit
	commit="$(git rev-parse 'HEAD')"

	local cache
	cache="$(cache_get_path)"

	local command_cache="$cache/${command_filename}"

	mkdir --parents "$command_cache"
	touch "$command_cache/$commit"
}

function cache_has {
	local command_filename
	command_filename="$(get_command_as_filename "$@")"

	local cache
	cache="$(cache_get_path)"

	local commit
	commit="$(git rev-parse 'HEAD')"

	if [[ -e $cache/$command_filename/$commit ]]; then
		echo 'true'
	else
		echo 'false'
	fi
}

function get_command_as_filename {
	local -a command=("$@")
	local filename="${command[*]@Q}"
	echo "${filename//\//-}"
}

function log {
	echo "[git-auto-check] $1" >&2
}

main "$@"
