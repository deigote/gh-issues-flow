function gh-issue-to-branch
	set issue_no $argv[1]
	set issue_title (ghi show $issue_no | head -n 1 | sed "s/^.$issue_no: //")
	echo feature/(command echo $issue_title | tr A-Z a-z | sed -e 's/[^a-zA-Z0-9\-]/-/g' | sed -e 's/^-*//' -e 's/-*$//')-$issue_no
end

function gh-issue-to-pull-request
        set issue_no $argv[1]
	if test (count $argv) -gt 1
		set master_branch $argv[2]
	else
		set master_branch master
	end
	set issue_title (gh-issue-to-branch $issue_no)
	set upstream_remote (git remote -v | grep -E "^upstream( |\t)" | grep push | awk '{print $2}' | cut -d':' -f2 | cut -d'/' -f1)
	set pull_request_cmd "ghi edit $issue_no -H \"$upstream_remote\":\"$issue_title\" -b $master_branch"
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
	end
end

function gh-issue-update-milestone
	set issue_no $argv[1]
	set unclean_milestones (ghi milestone --list | grep -E "[0-9]: ")
	set -e milestones
	for i in $unclean_milestones
		set milestones $milestones (trim $i)
	end
	print_msg "Do you want to change the milestone? Select the number and press enter or just press enter to skip this step"
	set milestone_idx 1 ; for i in $milestones ; echo "["$milestone_idx"] "$i ; set milestone_idx (expr $milestone_idx + 1) ; end
        set -e milestone_idx
        read milestone_idx -p 'echo "> "'
	if test ! -z "$milestone_idx"
		set milestone_title (echo $milestones[$milestone_idx] | awk -F': ' '{print $2}')
		set milestone_number (echo $milestones[$milestone_idx] | awk -F': ' '{print $1}')
		echo "Changing the milestone to '$milestone_title'"
		ghi edit $issue_no --milestone $milestone_number > /dev/null
	end
end

function gh-issue-flow
	set action $argv[1]
	set issue_no $argv[2]
	if test (count $argv) -gt 2
		set master_branch $argv[3]
	else
		set master_branch master
	end
        set origin_branch
        set branch_title (gh-issue-to-branch $issue_no)
	git show-ref --verify --quiet "refs/heads/$branch_title" ;and set is_new_branch false ;or set is_new_branch true

	if test $is_new_branch = 'false'
		print_msg "Checking out existing branch '$branch_title'"
		git checkout "$branch_title"
	end

	if test $action = 'start'
		if test $is_new_branch = 'true'
			git fetch upstream
			set branch_upstream "upstream/$branch_title"
			set branch_origin "upstream/$master_branch"
			print_msg "Creating new branch '$branch_title'"
			git checkout -b "$branch_title" "$branch_origin"
			if git branch -a | grep "remotes/$branch_upstream" > /dev/null
				print_msg "Setting existing remote branch $branch_upstream as upstream branch"
				git branch --set-upstream-to="$branch_upstream"
				git pull --ff-only
			else
				print_msg "Creating remote branch '$branch_upstream' as upstream branch"
				git push upstream $branch_title --set-upstream
			end
			print_msg "Claiming the issue..."
			ghi edit --claim $issue_no > /dev/null
			gh-issue-update-label $issue_no
		end
	else if test $action = 'publish' 
		print_msg "Pushing against origin"
		git push 
		gh-issue-update-label $issue_no
	else if test $action = 'merge'
		git checkout $master_branch
		git merge "$branch_title"
	else if test $action = 'end'
		print_msg "Pushing the branch"
		git push 
		print_msg "Merging the branch into $master_branch and pushing $master_branch against origin"
		git checkout $master_branch
		gh-issue-update-label $issue_no	
		gh-issue-to-pull-request $issue_no $master_branch
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
		case update-milestone
			gh-issue-update-milestone $argv[2..-1]
		case flow
			gh-issue-flow $argv[2..-1]
	end
end
