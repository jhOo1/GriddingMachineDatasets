module YamlBuilder

# 导出这个模块对外公开的函数
export build_yaml_string

# 辅助函数（模块内部可用）
function format_array(arr)
    if isempty(arr) return "[]" end
    if eltype(arr) <: AbstractString || typeof(first(arr)) <: AbstractString
        return "[" * join(["\"$x\"" for x in arr], ", ") * "]"
    else
        return "[" * join(arr, ", ") * "]"
    end
end

format_bool(b::Bool) = b ? "True" : "False"

# 主业务逻辑：拼接字符串
function build_yaml_string(payload)
    file_sec = """
    # File name patterns
    # Note that if YYYY does not exist, then it is not a duplicated task
    # These keys are mandatory:
    #     - PATTERN
    #     - PREFIX
    #     - NX
    #     - MT
    #     - VV
    FILE:
      PATTERN : "$(payload.PATTERN)"
      PREFIX  : $(format_array(payload.PREFIX))
      NX      : $(format_array(payload.NX))
      MT      : $(format_array(payload.MT))
    """
    
    if haskey(payload, :YYYY) && !isempty(payload.YYYY)
        file_sec *= "  YYYY    : $(format_array(payload.YYYY))\n"
    end
    
    file_sec *= "  VV      : $(format_array(payload.VV))\n\n"

    folder_sec = """
    # Folder structure for input and output
    FOLDER:
      ORIGINAL    : "$(payload.ORIGINAL)"
      REPROCESSED : "$(payload.REPROCESSED)"
      TARBALL     : "$(payload.TARBALL)"

    """

    data_sec = """
    # Data configuration
    # Note that the labels should match the PREFIX in FILE section
    DATA:
      ABOUT          : "$(payload.ABOUT)"
      CHANGE_LOGS    : $(format_array(payload.CHANGE_LOGS))
      LABEL          : $(format_array(payload.LABEL))
      LIMITS         : $(format_array(payload.LIMITS))
      REV_LAT        : $(format_bool(payload.REV_LAT))
    """

    if haskey(payload, :SCALING) && payload.SCALING != ""
        data_sec *= "  SCALING        : \"$(payload.SCALING)\"\n"
    end
    if haskey(payload, :SCALING_FACTOR) && !isempty(payload.SCALING_FACTOR)
        data_sec *= "  SCALING_FACTOR : $(format_array(payload.SCALING_FACTOR))\n"
    end

    data_sec *= """
      UNIT           : "$(payload.UNIT)"
      VERIFY_ONCE    : $(format_bool(payload.VERIFY_ONCE))

    """

    gm_sec = """
    # GriddingMachine configuration
    GRIDDINGMACHINE:
      TAG : $(payload.TAG)
    """

    return file_sec * folder_sec * data_sec * gm_sec
end

end # end of module