function TranslateTagTo4ComponentVersion {
    param (
        $TAG
    )

    $VERSION = $TAG -replace 'v', ''
    $VERSION = $VERSION -replace '-alpha', ''
    $VERSION = $VERSION -replace '-beta', ''
    $VERSION = $VERSION -replace '-rc', ''
    $VERSION = $VERSION -replace '-pre', ''
    $VERSION_COMPONENTS = $VERSION -split '\.'
    $VERSION_MAJOR = [int]$VERSION_COMPONENTS[0]
    $VERSION_MINOR = [int]$VERSION_COMPONENTS[1]
    $VERSION_PATCH = [int]$VERSION_COMPONENTS[2]
    $VERSION_PRERELEASE = 0
    if ($VERSION_COMPONENTS.Length -gt 3) {
      $VERSION_PRERELEASE = [int]$VERSION_COMPONENTS[3]
    }
    
    "$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH.$VERSION_PRERELEASE"
  }

  $CHANGELOG = ""

  $TAG_INDEX = 0
  $TAGS = git tag --list --sort=-v:refname
  $TAGS | ForEach-Object {
    $TAG = $_
    if ($TAG -like "v*") {
      $PREVIOUS_TAG = "v0.0.0"
      if ($TAG_INDEX -lt $TAGS.Length - 1) {
        $PREVIOUS_TAG = $TAGS[$TAG_INDEX + 1]
      }
      
      if (-not ($PREVIOUS_TAG -like "v*")) {
        $PREVIOUS_TAG = "v0.0.0"
      }
      
      $VERSION = TranslateTagTo4ComponentVersion($TAG)
      $PREVIOUS_VERSION = TranslateTagTo4ComponentVersion($PREVIOUS_TAG)

      $VERSION_COMPONENTS = $VERSION -split '\.'
      $VERSION_MAJOR = [int]$VERSION_COMPONENTS[0]
      $VERSION_MINOR = [int]$VERSION_COMPONENTS[1]
      $VERSION_PATCH = [int]$VERSION_COMPONENTS[2]
      $VERSION_PRERELEASE = [int]$VERSION_COMPONENTS[3]

      $PREVIOUS_VERSION_COMPONENTS = $PREVIOUS_VERSION -split '\.'
      $PREVIOUS_VERSION_MAJOR = [int]$PREVIOUS_VERSION_COMPONENTS[0]
      $PREVIOUS_VERSION_MINOR = [int]$PREVIOUS_VERSION_COMPONENTS[1]
      $PREVIOUS_VERSION_PATCH = [int]$PREVIOUS_VERSION_COMPONENTS[2]
      $PREVIOUS_VERSION_PRERELEASE = [int]$PREVIOUS_VERSION_COMPONENTS[3]
      
      $PREVIOUS_MAJOR_VERSION_NUMBER = $VERSION_MAJOR - 1;
      $PREVIOUS_MINOR_VERSION_NUMBER = $VERSION_MINOR - 1;
      $PREVIOUS_PATCH_VERSION_NUMBER = $VERSION_PATCH - 1;
      $PREVIOUS_PRERELEASE_VERSION_NUMBER = $VERSION_PRERELEASE - 1;

      if ($VERSION_PRERELEASE -gt $PREVIOUS_VERSION_PRERELEASE) {
        $VERSION_TYPE = "prerelease"
        $COMPARE_TAG = "$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH.$PREVIOUS_PRERELEASE_VERSION_NUMBER"
      } elseif ($VERSION_PATCH -gt $PREVIOUS_VERSION_PATCH) {
        $VERSION_TYPE = "patch"
        $COMPARE_TAG = "$VERSION_MAJOR.$VERSION_MINOR.$PREVIOUS_PATCH_VERSION_NUMBER.0"
      } elseif ($VERSION_MINOR -gt $PREVIOUS_VERSION_MINOR) {
        $VERSION_TYPE = "minor"
        $COMPARE_TAG = "$VERSION_MAJOR.$PREVIOUS_MINOR_VERSION_NUMBER.0.0"
      } elseif ($VERSION_MAJOR -gt $PREVIOUS_VERSION_MAJOR) {
        $VERSION_TYPE = "major"
        $COMPARE_TAG = "$PREVIOUS_MAJOR_VERSION_NUMBER.0.0.0"
      }

      if ($COMPARE_TAG.Contains("-")) {
        $COMPARE_TAG = $PREVIOUS_TAG
      }

      $COMPARE_VERSION = TranslateTagTo4ComponentVersion($COMPARE_TAG)

      if ($PREVIOUS_TAG -ne "v0.0.0") {
        $FOUND_COMPARE_TAG = $false
        $TAGS | ForEach-Object {
          if (-not $FOUND_COMPARE_TAG) {
            $OTHER_TAG = $_
            $OTHER_VERSION = TranslateTagTo4ComponentVersion($OTHER_TAG)
            if ($COMPARE_VERSION -eq $OTHER_VERSION) {
              $FOUND_COMPARE_TAG = $true
              $COMPARE_TAG = $OTHER_TAG
            }
          }
        }
        
        if (-not $FOUND_COMPARE_TAG) {
          $COMPARE_TAG = $PREVIOUS_TAG
        }
      }
      
      $EXCLUDE_BOTS = '^(?!.*(\[bot\]|github|ProjectDirector|SyncFileContents)).*$'
      $EXCLUDE_PRS = @'
^.*(Merge pull request|Merge branch 'main'|Updated packages in|Update.*package version).*$
'@


      $RANGE = "$TAG"
      if ($PREVIOUS_TAG -ne "v0.0.0") {
        $RANGE = "$COMPARE_TAG...$TAG"  
      }

      $COMMITS = git log --pretty=format:"%s ([@%aN](https://github.com/%aN))" --perl-regexp --regexp-ignore-case --grep="$EXCLUDE_PRS" --invert-grep --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" $RANGE | Sort-Object | Get-Unique

    #   $CONTRIBUTORS = git log --pretty=format:"[@%aN](https://github.com/%aN)" --perl-regexp --regexp-ignore-case --grep="$EXCLUDE_PRS" --invert-grep --committer="$EXCLUDE_BOTS" --author="$EXCLUDE_BOTS" $RANGE | Sort-Object | Get-Unique
    #   if ($CONTRIBUTORS.Length -eq 0) {
    #     $CONTRIBUTORS = git log --pretty=format:"[@%aN](https://github.com/%aN)" --perl-regexp --regexp-ignore-case --grep="$EXCLUDE_PRS" --invert-grep $RANGE | Sort-Object | Get-Unique
    #   }

      if ($VERSION_TYPE -ne "prerelease" -and $COMMITS.Length -gt 0) {
        $CHANGELOG += "## $TAG ($VERSION_TYPE)"
        $CHANGELOG += "`n"
        $CHANGELOG += "`n"
        # if ($COMPARE_TAG -ne "0.0.0.0") {
        #     $CHANGELOG += "### Changes since $COMPARE_TAG"
        #     $CHANGELOG += "`n"
        #     $CHANGELOG += "`n"
        # }

        $COMMITS | Where-Object { -not $_.Contains("Update VERSION to") -and -not $_.Contains("[skip ci]") } | ForEach-Object {
            $COMMIT = $_
            $CHANGELOG += "- $COMMIT"
            $CHANGELOG += "`n"
        }
        $CHANGELOG += "`n"
        # $CHANGELOG += "#### Contributors"
        # $CHANGELOG += "`n"
        # $CHANGELOG += "`n"
        # $CONTRIBUTORS | ForEach-Object {
        #     $CONTRIBUTOR = $_
        #     $CHANGELOG += "- $CONTRIBUTOR"
        #     $CHANGELOG += "`n"
        # }
        # $CHANGELOG += "`n"
      }
    }
    $TAG_INDEX += 1
  }

  Write-Host "CHANGELOG: $CHANGELOG"
  $CHANGELOG | Out-File -FilePath CHANGELOG.md -Encoding utf8

  $global:LASTEXITCODE = 0