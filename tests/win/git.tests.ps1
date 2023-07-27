Describe "Git" {
    BeforeAll {
        $Git = Get-InstalledSoftware | Where-Object {
            $PSItem.DisplayName -match "Git"
        }
    }
    It "Git is installed" {
        $Git.DisplayName | Should -Not -Be $null
    }

    It "Git Version is 2.36.1" {
        $Git.DisplayVersion | Should -Be "2.37.3"
    }
}