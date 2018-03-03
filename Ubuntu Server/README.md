## Deployment
Install all available packages:
     
     sudo ./deploy-<script>.sh full
     
List all available packages per category:

    ./deploy-<script>.sh --list

List all categories by name (no packages)
    
    ./deploy-<script>.sh --list | grep -i "\[+\]"

Dry run mode: Use this to print which packages are to be installed on your system.Already installed will be skipped and not be printed.

    ./deploy-<script>.sh --dry "category name"
    or
    ./deploy-<script>.sh --dry full

     