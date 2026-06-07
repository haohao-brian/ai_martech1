# AI Assistant Component
# Embeds an external chat bot (e.g. Ollama) via iframe.
# URL is read from app_configs$ai_assistant$url; empty -> empty-state.
#
# Principles: R09 UI-Server-Defaults, MP142 Configuration-Driven, UI_R026 sidebar 3-layer

ai_assistant_url <- function() {
  url <- tryCatch(app_configs$ai_assistant$url, error = function(e) NULL)
  if (is.null(url) || !nzchar(url)) NULL else url
}

ai_assistantUI <- function(id, translate = function(x) x) {
  ns <- NS(id)
  url <- ai_assistant_url()
  if (is.null(url)) {
    return(
      div(style = "padding:24px;",
        h4(translate("AI Assistant not configured")),
        p(translate("AI Assistant config missing"))
      )
    )
  }
  tagList(
    div(style = "margin-bottom:8px;",
      tags$small(translate("AI Assistant iframe hint"), " ",
                 tags$a(href = url, target = "_blank", translate("Open in new tab")))
    ),
    tags$iframe(
      src = url,
      style = "width:100%; height:calc(100vh - 180px); min-height:600px; border:none;",
      allow = "clipboard-read; clipboard-write"
    )
  )
}

ai_assistantServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    invisible(NULL)
  })
}

# Wrapper matching reportIntegrationComponent() shape so union can call uniformly.
ai_assistantComponent <- function(id, app_data_connection = NULL,
                                  comp_config = NULL, translate = function(x) x) {
  list(
    ui = list(
      filter  = NULL,
      display = ai_assistantUI(id, translate = translate)
    ),
    server = function(input, output, session, module_results = NULL) {
      ai_assistantServer(id)
    }
  )
}
