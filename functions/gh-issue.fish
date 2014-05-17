function gh-issue-to-branch
	set issue_no $argv[1]
	set issue_title (ghi show $issue_no | head -n 1 | sed "s/^.$issue_no: //")
	echo feature/(command echo $issue_title | tr A-Z a-z | sed -e 's/[^a-zA-Z0-9\-]/-/g' | sed -e 's/^-*//' -e 's/-*$//')-\#$issue_no
end

function gh-issue-to-pull-request
        set issue_no $argv[1]
	set issue_title (gh-issue-to-branch $issue_no)
	set origin_remote (git remote -v | grep -E "^origin( |\t)" | grep push | awk '{print $2}' | cut -d':' -f2 | cut -d'/' -f1)
	set pull_request_cmd "ghi edit $issue_no -H \"$origin_remote\":\"$issue_title\" -b develop"
	print_msg "Do you want to updating the issue to a pull request?"
	execute_on_confirm $pull_request_cmd
end

function gh-issue-update-label
	set issue_no $argv[1]
        set labels (ghi label --list)
	print_msg "Do you want to change the label? Select the number and press enter or just press enter to skip this step"
	set label_idx 1 ; for i in $labels ; echo "["$label_idx"] "$i ; set label_idx (expr $label_idx + 1) ; end
	set -e label_idx
	read label_idx -p 'echo "> "'
	if test ! -z "$label_idx" -a "$label_idx" -le (count $labels)
		echo "Changing the label to '$labels[$label_idx]'"
		ghi edit $issue_no --label $labels[$label_idx] > /dev/null
		ghi comment $issue_no -m "Label changed to '$labels[$label_idx]'" > /dev/null
	end
end

function gh-issue-flow
	set action $argv[1]
	set issue_no $argv[2]
        set branch_title (gh-issue-to-branch $issue_no)
	git show-ref --verify --quiet "refs/heads/$branch_title" ;and set is_new_branch false ;or set is_new_branch true

	if test $is_new_branch = 'false'
		print_msg "Checking out existing branch '$branch_title'"
		git checkout "$branch_title"
	end

	if test $action = 'start' 
		if test $is_new_branch = 'true'
			print_msg "Checking out new branch '$branch_title'"
			git checkout -b "$branch_title"
			print_msg "Claiming the issue..."
			ghi edit --claim $issue_no > /dev/null
			gh-issue-update-label $issue_no
		end
	else if test $action = 'publish' 
		print_msg "Pushing against origin"
		git push origin "$branch_title" --set-upstream
		gh-issue-update-label $issue_no
	else if test $action = 'merge'
		git checkout develop
		git merge "$branch_title"
	else if test $action = 'end'
		print_msg "Pushing the branch against origin"
		git push origin "$branch_title"
		print_msg "Merging the branch into develop and pushing develop against origin"
		git checkout develop
		git merge "$branch_title"
		git push origin develop
		gh-issue-update-label $issue_no	
		gh-issue-to-pull-request $issue_no
		print_msg "Deleting local branch"
		git branch -D "$branch_title"
	else
		print_error "Unknown action! Try start, publish or end"
	end
end

function gh-issue
	switch $argv[1]
		case to-branch
			gh-issue-to-branch $argv[2..-1]
		case to-pull-request
			gh-issue-to-pull-request $argv[2..-1]
		case update-label
			gh-issue-update-label $argv[2..-1]
		case flow
			gh-issue-flow $argv[2..-1]
	end
end
