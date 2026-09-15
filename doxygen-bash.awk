#!/usr/bin/awk -f
#
# doxygen-bash-docfilter.awk
#
# Documentation-led Doxygen preprocessor for Bash, implemented as a single
# portable awk file.
#
# The filter intentionally documents only symbols with Doxygen-style Bash
# comment blocks.  It is permissive about Bash formatting so author intent is
# not lost because of whitespace, indentation, or a harmless declaration style
# variation.
#
# Supported primary comment style:
#   ## @brief ...
#   ## @details
#   ## ...
#
# Supported documented declarations include:
#   name() {
#   name () {
#   function name() {
#   function name {
#   namespace::name() {
#   readonly NAME=value
#   readonly NAME
#   declare -r NAME=value
#   declare -a NAME=(...)
#   declare -A NAME=(...)
#   declare NAME
#   typeset NAME
#   export NAME=value
#   export NAME
#   local NAME=value
#   local NAME
#   NAME=value
#   NAME=(...)
#
# This is not a shell parser.  It is a documentation compiler for the subset of
# Bash declarations that can reasonably follow a Doxygen block.

BEGIN {
    strict = (strict ? strict : 0)
    keep_blanks = (compact ? 0 : 1)

    for (arg_index = 1; arg_index < ARGC; arg_index++) {
        if (ARGV[arg_index] == "--strict") {
            strict = 1
            ARGV[arg_index] = ""
        } else if (ARGV[arg_index] == "--compact") {
            keep_blanks = 0
            ARGV[arg_index] = ""
        }
    }

    reset_doc()
}

function reset_doc() {
    doc_count = 0
    doc_kind = ""
    doc_name = ""
    doc_namespace = ""
    doc_namespace_conflict = ""
    doc_module = ""
    doc_module_conflict = ""
    doc_module_invalid = ""
    doc_module_malformed = ""
    doc_module_seen = 0
    param_count = 0
    delete doc_lines
    delete param_names
    delete param_doc_lines
    delete emitted_param_names
}

function trim(s) {
    sub(/^[ \t\r\n]+/, "", s)
    sub(/[ \t\r\n]+$/, "", s)
    return s
}

function emit_blank() {
    if (keep_blanks) {
        print ""
    }
}

function warn(message) {
    print FILENAME ":" FNR ": warning: " message > "/dev/stderr"
    warning_count++
}

function fail_or_warn(message) {
    warn(message)
    if (strict) {
        error_count++
    }
}

function is_blank(line) {
    return (line ~ /^[ \t]*$/)
}

function is_doc_line(line) {
    return (line ~ /^[ \t]*##([ \t]|$)/)
}

function is_transparent_annotation(line,    s) {
    s = trim(line)
    return (s ~ /^#[ \t]*shellcheck[ \t]+disable=SC[0-9]+([ \t]*,[ \t]*SC[0-9]+)*[ \t]*$/)
}

function strip_doc_marker(line,    s) {
    s = line
    sub(/^[ \t]*##[ \t]?/, "", s)
    return s
}

function is_param_directive(meta) {
    return (meta ~ /^@param(\[(in|out|in,out)\])?[ \t]+/)
}

function record_module_directive(meta, directive,    s, module_name) {
    doc_module_seen = 1
    s = meta
    sub("^" directive, "", s)

    if (s !~ /^[ \t]+/) {
        if (doc_module_malformed == "") {
            doc_module_malformed = directive
        }
        return
    }

    s = trim(s)
    if (s == "" || s ~ /[ \t]/) {
        if (doc_module_malformed == "") {
            doc_module_malformed = directive
        }
        return
    }

    module_name = s
    if (!is_valid_identifier(module_name)) {
        if (doc_module_invalid == "") {
            doc_module_invalid = module_name
        }
        return
    }

    if (doc_module == "") {
        doc_module = module_name
    } else if (doc_module != module_name && doc_module_conflict == "") {
        doc_module_conflict = module_name
    }
}

function add_doc_line(line,    content, meta, namespace_name, module_directive) {
    content = strip_doc_marker(line)
    doc_lines[++doc_count] = content

    meta = trim(content)

    if (meta ~ /^@file([ \t]|$)/) {
        if (doc_kind == "") {
            doc_kind = "file"
        }
    } else if (meta ~ /^@namespace[ \t]+/) {
        namespace_name = parse_doc_symbol(meta, "@namespace")
        if (doc_namespace != "" && doc_namespace != namespace_name) {
            doc_namespace_conflict = namespace_name
        } else {
            doc_namespace = namespace_name
        }
    } else if (meta ~ /^@module([ \t]|$)/) {
        module_directive = "@module"
        record_module_directive(meta, module_directive)
    } else if (meta ~ /^@package([ \t]|$)/) {
        module_directive = "@package"
        record_module_directive(meta, module_directive)
    } else if (meta ~ /^@fn[ \t]+/) {
        doc_kind = "fn"
        doc_name = parse_doc_symbol(meta, "@fn")
    } else if (meta ~ /^@var[ \t]+/) {
        doc_kind = "var"
        doc_name = parse_doc_symbol(meta, "@var")
    } else if (is_param_directive(meta)) {
        param_count++
        param_names[param_count] = parse_param_name(meta)
        param_doc_lines[param_count] = doc_count
    }
}

function parse_doc_symbol(meta, directive,    s) {
    s = meta
    sub("^" directive "[ \t]+", "", s)
    s = trim(s)
    sub(/[ \t].*$/, "", s)
    sub(/\(.*$/, "", s)
    return s
}

function parse_param_name(meta,    s) {
    s = meta
    sub(/^@param(\[(in|out|in,out)\])?[ \t]+/, "", s)
    s = trim(s)
    sub(/[ \t].*$/, "", s)
    return s
}

function sanitize_identifier(name, fallback,    s) {
    s = name
    gsub(/^[.][.][.]/, "", s)
    gsub(/^--/, "", s)
    gsub(/\[\]$/, "", s)
    gsub(/[=]$/, "", s)
    gsub(/-/, "_", s)
    gsub(/[^A-Za-z0-9_:]/, "_", s)

    if (s == "") {
        s = fallback
    }
    if (s ~ /^[0-9]/) {
        s = "p_" s
    }

    return s
}

function unique_param_name(name,    base, n) {
    base = name
    n = 1
    while (param_seen[name]) {
        n++
        name = base "_" n
    }
    param_seen[name] = 1
    return name
}

function prepare_param_names(    i, clean) {
    delete param_seen
    delete emitted_param_names

    for (i = 1; i <= param_count; i++) {
        clean = sanitize_identifier(param_names[i], "arg")
        emitted_param_names[i] = unique_param_name(clean)
    }
}

function rewrite_param_name(line, old_name, new_name,    pos, tail, name_pos) {
    pos = index(line, "@param")
    if (pos == 0) {
        return line
    }

    tail = substr(line, pos + 6)
    if (!match(tail, /^(\[(in|out|in,out)\])?[ \t]+/)) {
        return line
    }

    name_pos = RLENGTH + 1
    return substr(line, 1, pos + 5) \
           substr(tail, 1, name_pos - 1) \
           new_name \
           substr(tail, name_pos + length(old_name))
}

function rewrite_param_doc_lines(    i, line_number) {
    for (i = 1; i <= param_count; i++) {
        line_number = param_doc_lines[i]
        doc_lines[line_number] = rewrite_param_name(doc_lines[line_number], param_names[i], emitted_param_names[i])
    }
}

function build_param_list(    i, joined) {
    joined = ""

    for (i = 1; i <= param_count; i++) {
        if (joined != "") {
            joined = joined ", "
        }
        joined = joined "String " emitted_param_names[i]
    }

    return joined
}

function emit_doc_block(extra_line, suppress_fn, suppress_module, structural_line,    i, line, meta) {
    print "/**"
    if (structural_line != "") {
        print " * " structural_line
    }
    for (i = 1; i <= doc_count; i++) {
        line = doc_lines[i]
        meta = trim(line)
        if (suppress_fn && (meta ~ /^@fn([ \t]|$)/ || meta ~ /^@namespace([ \t]|$)/)) {
            continue
        }
        if (suppress_module && (meta ~ /^@module([ \t]|$)/ || meta ~ /^@package([ \t]|$)/)) {
            continue
        }
        if (line == "") {
            print " *"
        } else {
            print " * " line
        }
    }
    if (extra_line != "") {
        print " * " extra_line
    }
    print " */"
}

function normalize_func_decl(line,    s) {
    s = line
    sub(/#.*/, "", s)
    s = trim(s)

    if (s ~ /^function[ \t]+/) {
        sub(/^function[ \t]+/, "", s)
    }

    sub(/[ \t]*\{[ \t;]*$/, "", s)
    s = trim(s)
    sub(/[ \t]*\(\)[ \t]*$/, "", s)
    s = trim(s)

    if (s ~ /^[A-Za-z_][A-Za-z0-9_:]*$/) {
        return s
    }

    return ""
}

function is_probable_function_decl(line) {
    return (normalize_func_decl(line) != "") && \
           (line ~ /^[ \t]*(function[ \t]+)?[A-Za-z_][A-Za-z0-9_:]*[ \t]*(\(\))?[ \t]*(\{|$)/)
}

function is_valid_identifier(name) {
    return (name ~ /^[A-Za-z_][A-Za-z0-9_]*$/)
}

function is_valid_namespace_path(path,    parts, count, i) {
    if (path == "") {
        return 0
    }

    count = split(path, parts, "::")
    for (i = 1; i <= count; i++) {
        if (!is_valid_identifier(parts[i])) {
            return 0
        }
    }

    return 1
}

function split_qualified_identity(identity, info,    parts, count, i, namespace_name) {
    delete info

    if (index(identity, "::") == 0) {
        return 0
    }

    count = split(identity, parts, "::")
    if (count < 2) {
        return 0
    }

    for (i = 1; i <= count; i++) {
        if (!is_valid_identifier(parts[i])) {
            return 0
        }
    }

    namespace_name = parts[1]
    for (i = 2; i < count; i++) {
        namespace_name = namespace_name "::" parts[i]
    }

    info["namespace"] = namespace_name
    info["member"] = parts[count]
    return 1
}

function resolve_module_name(    invalid) {
    invalid = 0

    if (!doc_module_seen) {
        return ""
    }

    if (doc_module_malformed != "") {
        fail_or_warn("malformed " doc_module_malformed " directive")
        invalid = 1
    }
    if (doc_module_invalid != "") {
        fail_or_warn("invalid module identifier " doc_module_invalid)
        invalid = 1
    }
    if (doc_module_conflict != "") {
        fail_or_warn("module metadata conflicts: " doc_module " and " doc_module_conflict)
        invalid = 1
    }

    if (invalid) {
        return ""
    }
    return doc_module
}

function resolve_function_identity(physical_name, info,    literal_info, documented_info, resolved_info, literal_qualified, documented_qualified, doc_has_qualification, valid_namespace, combined, identity, function_doc_name) {
    delete info

    function_doc_name = (doc_kind == "fn" ? doc_name : "")
    literal_qualified = split_qualified_identity(physical_name, literal_info)
    doc_has_qualification = (function_doc_name != "" && index(function_doc_name, "::") > 0)
    documented_qualified = 0
    valid_namespace = ""

    if (doc_namespace_conflict != "") {
        fail_or_warn("multiple @namespace directives conflict: " doc_namespace " and " doc_namespace_conflict)
    }

    if (doc_namespace != "") {
        if (is_valid_namespace_path(doc_namespace)) {
            valid_namespace = doc_namespace
        } else {
            fail_or_warn("invalid @namespace path " doc_namespace)
        }
    }

    if (doc_has_qualification) {
        if (split_qualified_identity(function_doc_name, documented_info)) {
            documented_qualified = 1
        } else {
            fail_or_warn("invalid qualified @fn identity " function_doc_name)
        }
    }

    if (literal_qualified) {
        identity = physical_name

        if (documented_qualified && function_doc_name != physical_name) {
            fail_or_warn("documentation identity " function_doc_name " conflicts with literal Bash declaration " physical_name)
        }

        if (valid_namespace != "" && valid_namespace != literal_info["namespace"]) {
            fail_or_warn("@namespace " valid_namespace " conflicts with literal Bash namespace " literal_info["namespace"])
        }

        if (function_doc_name != "" && !doc_has_qualification) {
            if (valid_namespace != "") {
                combined = valid_namespace "::" function_doc_name
                if (combined != physical_name) {
                    fail_or_warn("documentation identity " combined " conflicts with literal Bash declaration " physical_name)
                }
            } else if (function_doc_name != physical_name) {
                fail_or_warn("@fn documents " function_doc_name " but declaration is " physical_name)
            }
        }
    } else if (documented_qualified) {
        identity = function_doc_name

        if (valid_namespace != "" && valid_namespace != documented_info["namespace"]) {
            fail_or_warn("@namespace " valid_namespace " conflicts with qualified @fn namespace " documented_info["namespace"])
        }
    } else if (valid_namespace != "") {
        if (function_doc_name == "") {
            fail_or_warn("@namespace requires @fn for an unqualified Bash declaration")
            identity = physical_name
        } else if (doc_has_qualification) {
            identity = physical_name
        } else {
            identity = valid_namespace "::" function_doc_name
        }
    } else {
        identity = physical_name
        if (doc_namespace == "" && function_doc_name != "" && !doc_has_qualification && function_doc_name != physical_name) {
            fail_or_warn("@fn documents " function_doc_name " but declaration is " physical_name)
        }
    }

    info["identity"] = identity
    if (split_qualified_identity(identity, resolved_info)) {
        info["namespace"] = resolved_info["namespace"]
        info["member"] = resolved_info["member"]
    } else {
        info["namespace"] = ""
        info["member"] = identity
    }
}

function emit_function(namespace_name, member_name, module_name, module_requested,    params, namespace_parts, namespace_count, i, group_line) {
    prepare_param_names()
    rewrite_param_doc_lines()
    params = build_param_list()

    group_line = ""
    if (module_name != "") {
        group_line = "@ingroup " module_name
    }

    namespace_count = 0
    if (namespace_name != "") {
        namespace_count = split(namespace_name, namespace_parts, "::")
        for (i = 1; i <= namespace_count; i++) {
            print "namespace " namespace_parts[i] " {"
        }
    }

    emit_doc_block("", 1, module_requested, group_line)
    print "int " member_name "(" params ");"

    for (i = namespace_count; i >= 1; i--) {
        print "}"
    }
}

function count_top_level_words(s,    i, ch, quote, escaped, paren_depth, brace_depth, bracket_depth, in_word, count) {
    quote = ""
    escaped = 0
    paren_depth = 0
    brace_depth = 0
    bracket_depth = 0
    in_word = 0
    count = 0

    for (i = 1; i <= length(s); i++) {
        ch = substr(s, i, 1)

        if (escaped) {
            escaped = 0
            in_word = 1
            continue
        }

        if (quote != "") {
            if (quote != "'" && ch == "\\") {
                escaped = 1
            } else if (ch == quote) {
                quote = ""
            }
            in_word = 1
            continue
        }

        if (ch == "\\") {
            escaped = 1
            in_word = 1
            continue
        }
        if (ch == "'" || ch == "\"" || ch == "`") {
            quote = ch
            in_word = 1
            continue
        }
        if (ch == "(") {
            paren_depth++
            in_word = 1
            continue
        }
        if (ch == ")" && paren_depth > 0) {
            paren_depth--
            in_word = 1
            continue
        }
        if (ch == "{") {
            brace_depth++
            in_word = 1
            continue
        }
        if (ch == "}" && brace_depth > 0) {
            brace_depth--
            in_word = 1
            continue
        }
        if (ch == "[") {
            bracket_depth++
            in_word = 1
            continue
        }
        if (ch == "]" && bracket_depth > 0) {
            bracket_depth--
            in_word = 1
            continue
        }

        if ((ch == " " || ch == "\t") && paren_depth == 0 && brace_depth == 0 && bracket_depth == 0) {
            if (in_word) {
                count++
                in_word = 0
            }
            continue
        }

        in_word = 1
    }

    if (in_word) {
        count++
    }

    return count
}

function classify_variable(raw_line, info,    line, opts, name, value, eqpos, token) {
    delete info
    line = raw_line
    sub(/#.*/, "", line)
    line = trim(line)

    info["storage"] = "global"
    info["readonly"] = "no"
    info["exported"] = "no"
    info["declared"] = "no"
    info["explicit"] = "no"
    info["unsupported"] = ""
    info["array"] = "scalar"
    info["integer"] = "no"
    info["nameref"] = "no"
    info["case_transform"] = "none"
    info["name"] = ""
    info["type"] = "string"

    if (line ~ /^local([ \t]|$)/) {
        info["storage"] = "local"
        info["declared"] = "yes"
        info["explicit"] = "yes"
        sub(/^local[ \t]+/, "", line)
    } else if (line ~ /^readonly([ \t]|$)/) {
        info["readonly"] = "yes"
        info["declared"] = "yes"
        info["explicit"] = "yes"
        sub(/^readonly[ \t]+/, "", line)
    } else if (line ~ /^export([ \t]|$)/) {
        info["exported"] = "yes"
        info["declared"] = "yes"
        info["explicit"] = "yes"
        sub(/^export[ \t]+/, "", line)
    } else if (line ~ /^(declare|typeset)([ \t]|$)/) {
        info["declared"] = "yes"
        info["explicit"] = "yes"
        sub(/^(declare|typeset)[ \t]+/, "", line)
    }

    while (line ~ /^-[A-Za-z]+([ \t]|$)/) {
        token = line
        sub(/[ \t].*$/, "", token)
        opts = substr(token, 2)

        if (index(opts, "r")) info["readonly"] = "yes"
        if (index(opts, "x")) info["exported"] = "yes"
        if (index(opts, "a")) info["array"] = "indexed_array"
        if (index(opts, "A")) info["array"] = "associative_array"
        if (index(opts, "i")) info["integer"] = "yes"
        if (index(opts, "n")) info["nameref"] = "yes"
        if (index(opts, "l")) info["case_transform"] = "lowercase"
        if (index(opts, "u")) info["case_transform"] = "uppercase"

        sub(/^-[A-Za-z]+[ \t]*/, "", line)
        line = trim(line)
    }

    if (line == "") {
        return 0
    }

    if (info["explicit"] == "yes" && count_top_level_words(line) > 1) {
        info["unsupported"] = "multi_name"
        return -1
    }

    eqpos = index(line, "=")
    if (eqpos > 0) {
        name = trim(substr(line, 1, eqpos - 1))
        value = trim(substr(line, eqpos + 1))
    } else {
        if (info["declared"] != "yes") {
            return 0
        }
        name = line
        value = ""
    }

    sub(/[ \t].*$/, "", name)
    sub(/^[-+][A-Za-z]+[ \t]+/, "", name)

    if (name !~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
        return 0
    }

    if (info["array"] == "scalar" && value ~ /^\(/) {
        info["array"] = "indexed_array"
    }

    if (info["array"] == "associative_array") {
        info["type"] = "associative_array"
    } else if (info["array"] == "indexed_array") {
        info["type"] = "indexed_array"
    } else if (info["nameref"] == "yes") {
        info["type"] = "nameref"
    } else if (info["integer"] == "yes") {
        info["type"] = "integer"
    } else {
        info["type"] = "string"
    }

    info["name"] = name
    return 1
}

function variable_meta(info,    meta) {
    meta = "@details Bash variable: "

    if (info["storage"] == "local") {
        meta = meta "local "
    }
    if (info["exported"] == "yes") {
        meta = meta "exported "
    }
    if (info["readonly"] == "yes") {
        meta = meta "readonly "
    } else {
        meta = meta "read-write "
    }

    meta = meta info["type"]

    if (info["case_transform"] == "lowercase") {
        meta = meta " lowercase-transform"
    } else if (info["case_transform"] == "uppercase") {
        meta = meta " uppercase-transform"
    }

    return meta
}

function variable_pseudo_type(info,    type) {
    type = ""

    if (info["storage"] == "local") type = type "Local"
    if (info["exported"] == "yes") type = type "Exported"
    if (info["readonly"] == "yes") type = type "Readonly"

    if (info["type"] == "associative_array") {
        type = type "AssociativeArray"
    } else if (info["type"] == "indexed_array") {
        type = type "IndexedArray"
    } else if (info["type"] == "nameref") {
        type = type "NameReference"
    } else if (info["type"] == "integer") {
        type = type "Integer"
    } else {
        type = type "String"
    }

    return type
}

function emit_variable(info, module_name, module_requested,    type, group_line) {
    group_line = ""
    if (module_name != "") {
        group_line = "@ingroup " module_name
    }
    emit_doc_block(variable_meta(info), 0, module_requested, group_line)
    type = variable_pseudo_type(info)
    print type " " info["name"] ";"
}

function docs_are_file_only() {
    return (doc_count > 0 && doc_kind == "file")
}

function docs_are_module_definition() {
    return (doc_count > 0 && doc_module_seen && doc_kind == "" && doc_namespace == "" && param_count == 0)
}

function emit_module_definition(    module_name) {
    module_name = resolve_module_name()
    if (module_name != "") {
        emit_doc_block("", 0, 1, "@defgroup " module_name " " module_name)
    } else {
        emit_doc_block("@warning Invalid module metadata prevented group definition.", 0, 1, "")
    }
}

function flush_file_docs_if_needed() {
    if (docs_are_file_only()) {
        emit_doc_block("")
        reset_doc()
        return 1
    }
    return 0
}

function flush_module_docs_if_needed() {
    if (docs_are_module_definition()) {
        emit_module_definition()
        reset_doc()
        return 1
    }
    return 0
}

function flush_unmatched_docs(reason,    module_name) {
    if (doc_count > 0) {
        if (doc_module_seen) {
            module_name = resolve_module_name()
        }
        if (reason != "") {
            fail_or_warn(reason)
        }
        emit_doc_block("@warning No recognized Bash declaration was associated with this documentation block.", 0, doc_module_seen, "")
        reset_doc()
    }
}

{
    source_line = $0

    if (is_doc_line(source_line)) {
        add_doc_line(source_line)
        next
    }

    if (doc_count > 0) {
        if (is_blank(source_line)) {
            if (flush_file_docs_if_needed()) {
                emit_blank()
                next
            }
            if (flush_module_docs_if_needed()) {
                emit_blank()
            }
            next
        }

        if (flush_file_docs_if_needed()) {
            emit_blank()
        }

        if (doc_count > 0 && is_transparent_annotation(source_line)) {
            emit_blank()
            next
        }

        if (doc_count > 0 && docs_are_module_definition()) {
            if (is_probable_function_decl(source_line)) {
                fail_or_warn("module membership for function requires @fn")
                emit_doc_block("@warning Module metadata was not associated because explicit @fn metadata is required.", 0, 1, "")
                reset_doc()
                next
            }

            module_variable_status = classify_variable(source_line, module_var_info)
            if (module_variable_status != 0) {
                fail_or_warn("module membership for variable requires @var")
                emit_doc_block("@warning Module metadata was not associated because explicit @var metadata is required.", 0, 1, "")
                delete module_var_info
                reset_doc()
                next
            }
            delete module_var_info

            emit_module_definition()
            reset_doc()
            emit_blank()
            next
        }

        if (doc_count > 0 && is_probable_function_decl(source_line)) {
            fn_name = normalize_func_decl(source_line)
            if (doc_kind == "var") {
                fail_or_warn("@var block precedes function declaration " fn_name)
            }

            module_name = ""
            if (doc_module_seen) {
                module_name = resolve_module_name()
                if (doc_kind != "fn") {
                    fail_or_warn("module membership for function requires @fn")
                    module_name = ""
                }
            }

            resolve_function_identity(fn_name, fn_identity)
            emit_function(fn_identity["namespace"], fn_identity["member"], module_name, doc_module_seen)
            delete fn_identity
            reset_doc()
            next
        }

        if (doc_count > 0) {
            variable_status = classify_variable(source_line, var_info)

            if (variable_status < 0 && var_info["unsupported"] == "multi_name") {
                fail_or_warn("documented multi-name variable declarations are unsupported")
                emit_doc_block("@warning Multiple Bash variable names in one declaration are outside the supported association model.")
                delete var_info
                reset_doc()
                next
            }

            if (variable_status > 0) {
                module_name = ""
                if (doc_module_seen) {
                    module_name = resolve_module_name()
                    if (doc_kind != "var") {
                        fail_or_warn("module membership for variable requires @var")
                        module_name = ""
                    }
                }
                if (doc_namespace != "") {
                    fail_or_warn("@namespace is only supported for function documentation")
                }
                if (doc_kind == "fn") {
                    fail_or_warn("@fn block precedes variable declaration " var_info["name"])
                }
                if (doc_name != "" && doc_name != var_info["name"]) {
                    fail_or_warn("@var documents " doc_name " but declaration is " var_info["name"])
                }
                emit_variable(var_info, module_name, doc_module_seen)
                delete var_info
                reset_doc()
                next
            }

            delete var_info
        }

        flush_unmatched_docs("documentation block was not followed by a recognized declaration")
    }

    emit_blank()
}

END {
    if (doc_count > 0) {
        if (!flush_module_docs_if_needed()) {
            flush_unmatched_docs("documentation block reached end of file without a declaration")
        }
    }

    if (strict && (warning_count > 0 || error_count > 0)) {
        exit 1
    }
}
