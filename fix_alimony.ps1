$path = "lib/screens/alimony_calculator_screen.dart"
$content = Get-Content $path
$pre = $content[0..76]
$fix = "  Future<void> _calculateAlimony() async {", "    if (!_formKey.currentState!.validate()) return;"
$post = $content[309..($content.Count - 1)]
$final = $pre + $fix + $post
$final | Set-Content $path -Encoding UTF8
Write-Host "Fixed file structure."
