//! Reference harness for ntsc-rs add90f5bf1bf7e3c573e4e945a16f44a82941b51.
//! Upstream is MIT OR ISC OR Apache-2.0; its original sources/notices stay intact.
use ntsc_rs::NtscEffect;
use ntsc_rs::settings::standard::NtscEffectFullSettings;
use ntsc_rs::settings::{SettingDescriptor, SettingKind, SettingsList};
use ntsc_rs::yiq_fielding::{BlitInfo, DeinterlaceMode, Rgbx, YiqView};
use serde_json::{Value, json};
use std::{error::Error, fs};

type Result<T> = std::result::Result<T, Box<dyn Error>>;

fn descriptor(d: &SettingDescriptor<NtscEffectFullSettings>) -> Value {
    let mut v = json!({"id": d.id.id, "name": d.id.name, "label": d.label});
    if let Some(desc) = d.description {
        v["description"] = json!(desc);
    }
    match &d.kind {
        SettingKind::Boolean => v["type"] = json!("boolean"),
        SettingKind::Percentage { logarithmic } => {
            v["type"] = json!("percentage");
            v["min"] = json!(0);
            v["max"] = json!(1);
            v["logarithmic"] = json!(logarithmic);
        }
        SettingKind::IntRange { range } => {
            v["type"] = json!("int");
            v["min"] = json!(range.start());
            v["max"] = json!(range.end());
        }
        SettingKind::FloatRange { range, logarithmic } => {
            v["type"] = json!("float");
            v["min"] = json!(range.start());
            v["max"] = json!(range.end());
            v["logarithmic"] = json!(logarithmic);
        }
        SettingKind::Enumeration { options } => {
            v["type"] = json!("enum");
            v["options"] = options
                .iter()
                .map(|o| {
                    let mut v = json!({"index": o.index, "label": o.label});
                    if let Some(d) = o.description {
                        v["description"] = json!(d);
                    }
                    v
                })
                .collect();
        }
        SettingKind::Group { children } => {
            v["type"] = json!("group");
            v["children"] = children.iter().map(descriptor).collect();
        }
    }
    v
}

fn defaults(list: &SettingsList<NtscEffectFullSettings>) -> Result<Value> {
    // FullSettings derives its default from the current NtscEffect::default().
    Ok(serde_json::from_str(
        &list.to_json_string(&NtscEffectFullSettings::default())?,
    )?)
}

fn run() -> Result<()> {
    let a: Vec<String> = std::env::args().collect();
    let list = SettingsList::<NtscEffectFullSettings>::new();
    if a.len() == 4 && a[1] == "metadata" {
        let descriptors: Vec<_> = list.setting_descriptors.iter().map(descriptor).collect();
        fs::write(&a[2], serde_json::to_string_pretty(&descriptors)?)?;
        fs::write(&a[3], serde_json::to_string_pretty(&defaults(&list)?)?)?;
        println!("Wrote canonical descriptors and current defaults");
        return Ok(());
    }
    if !(a.len() == 8 || a.len() == 9) || (a[1] != "process" && a[1] != "roundtrip") {
        return Err("usage: ntscrt-reference metadata DESCRIPTORS.json DEFAULTS.json | process|roundtrip WIDTH HEIGHT FRAME SETTINGS.json INPUT.rgba OUTPUT.rgba [OUTPUT.yiq.f32]".into());
    }
    let width: usize = a[2].parse()?;
    let height: usize = a[3].parse()?;
    let frame: usize = a[4].parse()?;
    if width == 0 || height == 0 {
        return Err("dimensions must be positive".into());
    }
    let size = width
        .checked_mul(height)
        .and_then(|v| v.checked_mul(4))
        .ok_or("image size overflow")?;
    let mut merged = defaults(&list)?;
    let overrides: Value = serde_json::from_slice(&fs::read(&a[5])?)?;
    for (key, value) in overrides
        .as_object()
        .ok_or("settings must be a flat JSON object")?
    {
        if !merged.as_object().unwrap().contains_key(key) {
            return Err(format!("unknown canonical setting: {key}").into());
        }
        merged[key] = value.clone();
    }
    let settings = list.from_json(&serde_json::to_string(&merged)?)?;
    let effect: NtscEffect = (&settings).into();
    let mut rgba = fs::read(&a[6])?;
    if rgba.len() != size {
        return Err(format!("expected {size} input bytes, got {}", rgba.len()).into());
    }
    let field = effect.use_field.to_yiq_field(frame);
    let mut storage = vec![0f32; YiqView::buf_length_for((width, height), field)];
    let mut view = YiqView::from_parts(&mut storage, (width, height), field);
    let blit = BlitInfo::from_full_frame(width, height, width * 4);
    view.set_from_strided_buffer::<Rgbx, u8, _>(&rgba, blit, ());
    if a[1] == "process" {
        effect.apply_effect_to_yiq(&mut view, frame, [1.0, 1.0]);
    }
    if a.len() == 9 {
        let bytes: Vec<u8> = view
            .y
            .iter()
            .chain(view.i.iter())
            .chain(view.q.iter())
            .flat_map(|v| v.to_le_bytes())
            .collect();
        fs::write(&a[8], bytes)?;
    }
    view.write_to_strided_buffer::<Rgbx, u8, _>(&mut rgba, blit, DeinterlaceMode::Bob, ());
    fs::write(&a[7], &rgba)?;
    println!(
        "Processed {width}x{height}, frame={frame}, field={field:?}, field_rows={}",
        view.num_rows()
    );
    Ok(())
}
fn main() {
    if let Err(e) = run() {
        eprintln!("{e}");
        std::process::exit(1);
    }
}
