# github-repoCleaner-Utility
# Create masterRepoList.txt and update the below github repo in the same.
github/docs
github/gh-ost
github/dmca
github/DPG-guidance


#Overview of cleanup activity
1.Reads repository names from masterRepoList.txt.
2.Fetches all branches in each repository.
3.Identifies branches older than 1 year.
4.Displays stale branches and asks for user confirmation.
5.Deletes selected branches.
6.Saves the cleanup summary in cleanup_summary.txt.
