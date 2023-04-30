mod app;

use crate::app::App;
use tracing_subscriber::{
    fmt::{
        format::{FmtSpan, Pretty},
        time::UtcTime,
    },
    prelude::*,
};
use tracing_web::{performance_layer, MakeConsoleWriter};
use wasm_bindgen::prelude::*;

fn init_logging() {
    let fmt_layer = tracing_subscriber::fmt::layer()
        .with_ansi(false) // only partially supported across browsers
        .with_timer(UtcTime::rfc_3339()) // std::time is not available in browsers
        .with_writer(MakeConsoleWriter) // write events to the console
        .with_span_events(FmtSpan::ACTIVE);
    let perf_layer = performance_layer().with_details_from_fields(Pretty::default());

    tracing_subscriber::registry()
        .with(fmt_layer)
        .with(perf_layer)
        .init();
}

#[wasm_bindgen]
pub fn run_app() -> Result<(), JsValue> {
    init_logging();
    tracing::info!("Starting up yew app");

    yew::Renderer::<App>::new().render();

    Ok(())
}
