library(plumber)
library(randomForest)
library(jsonlite)

# ─────────────────────────────
# Enable CORS (allows browser requests)
# ─────────────────────────────

#* @filter cors
function(req, res){
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  
  if(req$REQUEST_METHOD == "OPTIONS"){
    res$status <- 200
    return(list())
  }
  
  plumber::forward()
}


# ─────────────────────────────
# Load trained models
# ─────────────────────────────

resolve_model_path <- function(filename) {
  candidates <- c(
    file.path("outputs", "model", filename),
    file.path("..", "..", "outputs", "model", filename),
    file.path("..", "outputs", "model", filename)
  )

  for (path in candidates) {
    if (file.exists(path)) {
      return(path)
    }
  }

  stop(
    paste0(
      "Model file not found: ", filename,
      ". Checked: ", paste(candidates, collapse = ", ")
    )
  )
}

rf_stage1 <- readRDS(resolve_model_path("rf_stage1_binary.rds"))
rf_stage2 <- readRDS(resolve_model_path("rf_stage2_multiclass.rds"))


# ─────────────────────────────
# Health check endpoint
# ─────────────────────────────

#* @get /
#* @serializer json
function() {
  list(status = "ECG Arrhythmia API running successfully 🚀")
}


# ─────────────────────────────
# Prediction endpoint
# Accepts JSON (72-feature input)
# ─────────────────────────────

#* Predict ECG condition using JSON input
#* @post /predict
#* @serializer json
function(req){
  
  tryCatch({
    
    # Read JSON body from request
    body <- jsonlite::fromJSON(req$postBody)
    
    # Convert to dataframe
    input <- as.data.frame(body)
    
    # Get required feature names from model
    required_cols <- rownames(rf_stage1$importance)
    
    # Check missing columns
    missing_cols <- setdiff(required_cols, colnames(input))
    
    if(length(missing_cols) > 0){
      stop(paste("Missing columns:", paste(missing_cols, collapse=", ")))
    }
    
    # Reorder columns correctly
    input <- input[, required_cols, drop = FALSE]
    
    # Stage 1 prediction (Normal vs Abnormal)
    stage1 <- predict(rf_stage1, input)
    
    if(stage1 == "Normal"){
      return(list(
        prediction = "Normal ECG ✅"
      ))
    }
    
    # Stage 2 prediction (Arrhythmia type)
    stage2 <- predict(rf_stage2, input)
    
    return(list(
      prediction = "Abnormal ECG ⚠️",
      arrhythmia_type = as.character(stage2)
    ))
    
  }, error=function(e){
    
    return(list(
      error = "Prediction failed ❌",
      message = e$message
    ))
    
  })
}