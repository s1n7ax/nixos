{ ... }:
{
  editorconfig = {
    enable = true;
    settings = {
      "*" = {
        indent_style = "tab";
        indent_size = "tab";
        tab_width = 2;
        charset = "utf-8";
        end_of_line = "lf";
        trim_trailing_whitespace = true;
        insert_final_newline = "true";
        max_line_length = 80;
      };

      "*.md" = {
        indent_style = "space";
        indent_size = 2;
        tab_width = 2;
      };
    };
  };
}
