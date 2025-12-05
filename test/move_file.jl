using FilePathsBase 

# 定义核心路径
public_dir = "/mnt/net/emerald/GriddingMachine/public";
target_dir = "/mnt/net/emerald/GriddingMachine/original/v0";

# 确保目标文件夹存在，不存在则创建
isdir(target_dir) || mkpath(target_dir);

processed_count = 0;  # 记录已处理的符合条件的文件夹数量

# 遍历public下的所有直接子文件夹
for subdir in readdir(public_dir; join=true)
    if !isdir(subdir)
        continue;
    end
    
    # 检查当前子文件夹下是否存在GRIDDINGMACHINE（文件/文件夹均可）
    griddingmachine_path = joinpath(subdir, "GRIDDINGMACHINE");
    if ispath(griddingmachine_path)
        processed_count += 1  # 符合条件，计数+1
        
        # 遍历当前子文件夹下的所有.nc文件
        for nc_file in readdir(subdir; join=true)
            # 仅处理.nc后缀的文件（排除文件夹）
            if isfile(nc_file) && endswith(lowercase(nc_file), ".nc")
                # 构造目标文件的完整路径
                target_file = joinpath(target_dir, basename(nc_file));
                
                # 新增：判断目标文件是否已存在，存在则跳过
                if isfile(target_file)
                    @warn "  跳过文件（目标路径已存在）: $(nc_file)"
                    continue  # 跳过当前文件，处理下一个
                end
                
                # 移动文件（无重名时执行）
                try
                    mv(nc_file, target_file; force=true);
                catch e
                    @error "  移动文件失败" file=nc_file error=e
                end
            end
        end
    end
end
println("\n文件移动任务执行完成，共处理了$(processed_count)个符合条件的文件夹")