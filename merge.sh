git switch main
sleep 1
echo "---------------------------------"
echo "Switched to main"
echo "---------------------------------"
git push -u origin
sleep 1
echo "---------------------------------"
echo "Pushed main to origin"
echo "---------------------------------"
git merge testing
sleep 1
echo "---------------------------------"
echo "Merged testing into main"
echo "---------------------------------"
git add .
sleep 1
echo "---------------------------------"
echo "Added changes to main"
echo "---------------------------------"
git commit --allow-empty-message -m ""
sleep 1
echo "---------------------------------"
echo "Committed changes to main"
echo "---------------------------------"
git push
sleep 1
echo "---------------------------------"
echo "Pushed main to origin"
echo "---------------------------------"
git switch testing
sleep 1
echo "---------------------------------"
echo "Switched to testing"
echo "---------------------------------"
git push -u origin
sleep 1
echo "---------------------------------"
echo "Pushed testing to origin"
echo "---------------------------------"
