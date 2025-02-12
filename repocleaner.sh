#!/bin/bash

# GitHub Personal Access Token (set as env variable for security)
GITHUB_TOKEN=${GITHUB_TOKEN:-""}
REPO_LIST_FILE="masterRepoList.txt"
TIME_WINDOW_DAYS=365
SUMMARY_FILE="cleanup_summary.txt"

# Ensure GitHub token is set
if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "Error: GITHUB_TOKEN is not set. Please export it before running the script."
    exit 1
fi

# Ensure repo list file exists
if [[ ! -f "$REPO_LIST_FILE" ]]; then
    echo "Error: File '$REPO_LIST_FILE' not found!"
    exit 1
fi

# Function to fetch all branches in a repo
get_branches() {
    local repo=$1
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
         "https://api.github.com/repos/$repo/branches" | jq -r '.[].name'
}

# Function to fetch last commit date for a branch
get_last_commit_date() {
    local repo=$1
    local branch=$2
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
         "https://api.github.com/repos/$repo/commits/$branch" | jq -r '.commit.committer.date'
}

# Function to delete a branch
delete_branch() {
    local repo=$1
    local branch=$2
    curl -X DELETE -s -H "Authorization: token $GITHUB_TOKEN" \
         "https://api.github.com/repos/$repo/git/refs/heads/$branch"
}

# Cleanup summary
echo "GitHub Repo Cleanup Summary - $(date)" > "$SUMMARY_FILE"

# Process each repository
while read -r repo; do
    echo "Processing repository: $repo"

    # Get all branches
    branches=$(get_branches "$repo")
    
    stale_branches=()
    for branch in $branches; do
        last_commit_date=$(get_last_commit_date "$repo" "$branch")
        if [[ -z "$last_commit_date" ]]; then
            echo "Skipping branch '$branch' (Could not fetch commit date)"
            continue
        fi
        
        commit_epoch=$(date -d "$last_commit_date" +%s)
        current_epoch=$(date +%s)
        age_days=$(( (current_epoch - commit_epoch) / 86400 ))

        if [[ $age_days -gt $TIME_WINDOW_DAYS ]]; then
            stale_branches+=("$branch")
        fi
    done

    # If no stale branches, continue
    if [[ ${#stale_branches[@]} -eq 0 ]]; then
        echo "No stale branches found for $repo."
        continue
    fi

    # List stale branches
    echo "Stale branches found in $repo:"
    for i in "${!stale_branches[@]}"; do
        echo "$((i+1)). ${stale_branches[i]}"
    done

    # Get user confirmation
    echo "Enter numbers of branches to delete (comma-separated) or 'all' to delete all:"
    read -r user_input
    selected_branches=()

    if [[ "$user_input" == "all" ]]; then
        selected_branches=("${stale_branches[@]}")
    else
        IFS=',' read -r -a indexes <<< "$user_input"
        for idx in "${indexes[@]}"; do
            selected_branches+=("${stale_branches[$((idx-1))]}")
        done
    fi

    # Delete selected branches
    for branch in "${selected_branches[@]}"; do
        echo "Deleting branch '$branch' from '$repo'..."
        delete_branch "$repo" "$branch"
        echo "Deleted: $repo -> $branch" >> "$SUMMARY_FILE"
    done

done < "$REPO_LIST_FILE"

echo "Cleanup summary saved to $SUMMARY_FILE"
