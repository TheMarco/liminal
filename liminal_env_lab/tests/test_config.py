from liminal_lab.config import bundled_presets_dir, bundled_profiles_dir, list_json_ids, load_preset, load_profile


EXPECTED = {"vegas_hotel", "office", "annex", "airport", "mall", "prison", "pool_rooms", "high_school", "asylum", "brutalist", "upside_down"}


def test_all_profiles_load_and_define_effects():
    assert set(list_json_ids(bundled_profiles_dir())) == EXPECTED
    for profile_id in EXPECTED:
        profile = load_profile(profile_id)
        assert profile.id == profile_id
        assert {"moisture", "dirt", "carpet_stains", "organic_growth"} <= profile.effects.keys()


def test_presets_load():
    assert {"balanced", "subtle", "aggressive"} <= set(list_json_ids(bundled_presets_dir()))
    assert load_preset("balanced").parameters["moisture"]["scale"] == 1.0
