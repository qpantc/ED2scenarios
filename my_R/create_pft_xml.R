generate_pft_xml <- function(data, filename) {
  # 1. 创建根节点
  doc <- xml_new_document()
  root <- xml_add_child(doc, "config")
  
  # 2. (可选) 添加非 PFT 的固定节点，如 radiation
  rad_node <- xml_add_child(root, "radiation")
  xml_add_child(rad_node, "lai_min", 0.01)
  
  # 3. 获取所有唯一的 PFT 编号
  pft_ids <- unique(data$pft)
  
  # 4. 循环每一个 PFT
  for (id in pft_ids) {
    pft_node <- xml_add_child(root, "pft")
    
    # 首先添加 <num> 节点 (这是 PFT 的 ID)
    xml_add_child(pft_node, "num", id)
    
    # 筛选出当前 PFT 的所有参数行
    current_pft_data <- data[data$pft == id, ]
    
    # 循环添加每一个参数
    for (i in 1:nrow(current_pft_data)) {
      param_name <- current_pft_data$parameter[i]
      param_value <- current_pft_data$value[i]
      
      xml_add_child(pft_node, param_name, param_value)
    }
  }
  
  # 5. 保存
  write_xml(doc, filename, format = TRUE)
  message("XML 文件已生成: ", filename)
}

# 运行函数
generate_pft_xml(params_df, "pft_config_long.xml")