import os

def replace_in_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    import_statement = "import 'package:sarge_depo_app/core/utils/snackbar_utils.dart';\n"

    new_content = content.replace('ScaffoldMessenger.of(context).showSnackBar(', 'TopSnackBar.showSnackBar(context, ')
    new_content = new_content.replace('ScaffoldMessenger.of(ctx).showSnackBar(', 'TopSnackBar.showSnackBar(ctx, ')
    new_content = new_content.replace('messenger?.showSnackBar(', 'TopSnackBar.showSnackBar(context, ')

    if new_content != content:
        if 'snackbar_utils.dart' not in new_content:
            first_import_idx = new_content.find('import ')
            if first_import_idx != -1:
                end_of_line = new_content.find('\n', first_import_idx)
                new_content = new_content[:end_of_line+1] + import_statement + new_content[end_of_line+1:]
            else:
                new_content = import_statement + new_content
            
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f'Updated {filepath}')

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            replace_in_file(os.path.join(root, file))
