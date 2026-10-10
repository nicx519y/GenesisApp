import argparse
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location("l10n_workflow", Path(__file__).with_name("l10n.py"))
l10n = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(l10n)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="worldo-l10n-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.rules_dir = self.root / "docs/l10n"
        self.rules_dir.mkdir(parents=True)
        self.tool_dir = self.root / "tool/l10n"
        self.tool_dir.mkdir(parents=True)
        self.arb_dir = self.root / "lib/l10n"
        self.arb_dir.mkdir(parents=True)
        page_dir = self.root / "lib/pages/me"
        page_dir.mkdir(parents=True)
        self.profiles = {
            "source": {"api_code": "en", "arb_locale": "en", "display_name": "English"},
            "targets": {
                "es": {"arb_locale": "es", "display_name": "Español", "style": "Latin America, tú", "plural_policy": "inflected"},
                "ja": {"arb_locale": "ja", "display_name": "日本語", "style": "Polite Japanese", "plural_policy": "uninflected"}
            }
        }
        self.save(self.rules_dir / "language-profiles.json", self.profiles)
        self.save(self.rules_dir / "glossary.json", {
            "preserve": ["Worldo"], "literal_markers": {}, "terms": {"Save": {"es": "Guardar", "ja": "保存"}}
        })
        (self.rules_dir / "translation-rules.md").write_text("Translate UI according to its scene.")
        (self.arb_dir / "app_language_controller.dart").write_text(
            "languageCodes = {'en', 'es', 'ja'}; supportedLocales = [Locale('en'), Locale('es'), Locale('ja')];"
        )
        (page_dir / "language_page.dart").write_text(
            "[(Locale('en'), 'English'), (Locale('es'), 'Español'), (Locale('ja'), '日本語')]"
        )
        (page_dir / "settings_page.dart").write_text(
            "{'en': 'English', 'es': 'Español', 'ja': '日本語'}"
        )
        self.source = {
            "@@locale": "en", "saveAction": "Save", "@saveAction": {"description": "Editor: save button for existing content."},
            "greeting": "Hello {name}", "@greeting": {"description": "Profile greeting; name is the user's display name.",
                                                       "placeholders": {"name": {"type": "String"}}}
        }
        self.save(self.arb_dir / "app_en.arb", self.source)
        for code, values in {"es": {"saveAction": "Guardar", "greeting": "Hola {name}"},
                             "ja": {"saveAction": "保存", "greeting": "こんにちは、{name}"}}.items():
            self.save(self.arb_dir / f"app_{code}.arb", {
                **copy.deepcopy(self.source), "@@locale": code, **values
            })
        workflow = self.workflow()
        state = {"version": 1, "languages": {}}
        for code in workflow.targets:
            state["languages"][code] = {
                "guidance_hash": workflow.guidance_hash(code),
                "entries": {key: workflow.record(key, workflow.catalogs[code][key], "baseline")
                            for key in l10n.messages(workflow.source)}
            }
        self.save(workflow.state_path, state)

    def save(self, path, value):
        path.write_text(l10n.encoded(value), encoding="utf-8")

    def workflow(self):
        return l10n.Workflow(self.root)

    def change_source(self, key="saveAction", text="Save changes"):
        source = l10n.read_json(self.arb_dir / "app_en.arb")
        source[key] = text
        self.save(self.arb_dir / "app_en.arb", source)

    def response(self, batch, text="Guardar cambios"):
        return {"batch_id": l10n.digest(batch["payload"]), "translations": [{"key": item["key"], "text": text, "status": "translated", "note": ""}
                                 for item in batch["payload"]["items"]]}

    def test_baseline_is_complete_and_noop_keeps_every_file_unchanged(self):
        workflow = self.workflow()
        workflow.check()
        before = workflow.snapshot()
        workflow.apply_responses([], [], before)
        self.assertEqual(before, workflow.snapshot())

    def test_changed_source_and_description_are_stale_even_with_existing_translation(self):
        self.change_source()
        workflow = self.workflow()
        self.assertEqual(workflow.pending("es"), ["saveAction"])
        with self.assertRaisesRegex(l10n.L10nError, "stale/untranslated"):
            workflow.check()
        source = l10n.read_json(self.arb_dir / "app_en.arb")
        source["saveAction"] = "Save"
        source["@saveAction"]["description"] = "Account profile: persist all edited fields."
        self.save(self.arb_dir / "app_en.arb", source)
        self.assertEqual(self.workflow().pending("ja"), ["saveAction"])

    def test_incremental_response_only_updates_requested_key_and_state(self):
        self.change_source()
        workflow = self.workflow()
        original_greeting = workflow.catalogs["es"]["greeting"]
        batches = workflow.batches(["es", "ja"], 20)
        responses = [self.response(batches[0]), self.response(batches[1], "変更を保存")]
        workflow.apply_responses(batches, responses, workflow.snapshot())
        after = self.workflow()
        after.check()
        self.assertEqual(after.catalogs["es"]["greeting"], original_greeting)
        self.assertEqual(after.state["languages"]["es"]["entries"]["saveAction"]["status"], "ai")

    def test_single_language_can_finish_new_key_while_others_remain_stale(self):
        self.source["closeAction"] = "Close"
        self.source["@closeAction"] = {"description": "Editor: dismiss the preview without saving."}
        self.save(self.arb_dir / "app_en.arb", self.source)
        workflow = self.workflow()
        batches = workflow.batches(["es"], 20)
        workflow.apply_responses(batches, [self.response(batches[0], "Cerrar")], workflow.snapshot())
        after = self.workflow()
        self.assertEqual(after.pending("es"), [])
        self.assertEqual(after.pending("ja"), ["closeAction"])
        with self.assertRaises(l10n.L10nError):
            after.check()

    def test_reviewed_unchanged_copy_is_preserved_but_source_change_invalidates_review(self):
        workflow = self.workflow()
        args = argparse.Namespace(language="es", key=["greeting"], note="Human confirmed the profile greeting.", status="reviewed")
        l10n.accept(workflow, args)
        self.change_source()
        workflow = self.workflow()
        self.assertEqual(workflow.pending("es"), ["saveAction"])
        batch = workflow.batches(["es"], 20)
        workflow.apply_responses(batch, [self.response(batch[0])], workflow.snapshot())
        entry = self.workflow().state["languages"]["es"]["entries"]["greeting"]
        self.assertEqual(entry["status"], "reviewed")
        self.change_source("greeting", "Welcome {name}")
        self.assertEqual(self.workflow().pending("es"), ["greeting"])

    def test_direct_translation_edit_cannot_silently_pass(self):
        catalog = l10n.read_json(self.arb_dir / "app_es.arb")
        catalog["saveAction"] = "Guardar cambios"
        self.save(self.arb_dir / "app_es.arb", catalog)
        with self.assertRaisesRegex(l10n.L10nError, "edited outside workflow"):
            self.workflow().check()
        workflow = self.workflow()
        l10n.accept(workflow, argparse.Namespace(language="es", key=["saveAction"],
                                               status="manual", note="Adjusted button wording."))
        self.workflow().check()

    def test_profile_change_only_marks_that_language_stale(self):
        self.profiles["targets"]["es"]["style"] = "Latin America, tú, avoid vosotros."
        self.save(self.rules_dir / "language-profiles.json", self.profiles)
        self.assertEqual(len(self.workflow().pending("es")), 2)
        self.assertEqual(self.workflow().pending("ja"), [])

    def test_new_language_requires_complete_glossary_and_client_registration(self):
        self.profiles["targets"]["fr"] = {"arb_locale": "fr", "display_name": "Français", "plural_policy": "inflected"}
        self.save(self.rules_dir / "language-profiles.json", self.profiles)
        with self.assertRaisesRegex(l10n.L10nError, "glossary is incomplete"):
            self.workflow().pending("fr")
        glossary = l10n.read_json(self.rules_dir / "glossary.json")
        glossary["terms"]["Save"]["fr"] = "Enregistrer"
        self.save(self.rules_dir / "glossary.json", glossary)
        workflow = self.workflow()
        self.assertEqual(len(workflow.pending("fr")), 2)
        self.assertTrue(workflow.registration_errors())

    def test_unregistered_arb_catalog_is_not_silently_ignored(self):
        self.save(self.arb_dir / "app_fr.arb", {**self.source, "@@locale": "fr"})
        with self.assertRaisesRegex(l10n.L10nError, "add a language profile"):
            self.workflow().check()

    def test_ambiguous_new_copy_is_blocked_until_scene_is_supplied(self):
        self.source["openAction"] = "Open"
        self.source["@openAction"] = {"description": "UI text"}
        self.save(self.arb_dir / "app_en.arb", self.source)
        with self.assertRaisesRegex(l10n.L10nError, "specific scene"):
            self.workflow().batches(["es"], 20)

    def test_failed_or_unconfirmed_batch_never_partially_writes(self):
        self.change_source()
        workflow = self.workflow()
        batches = workflow.batches(["es", "ja"], 20)
        before = workflow.snapshot()
        responses = [self.response(batches[0]), self.response(batches[1])]
        responses[1]["translations"][0].update(status="needs_confirmation", note="Meaning of save is ambiguous.")
        with self.assertRaisesRegex(l10n.L10nError, "needs confirmation"):
            workflow.apply_responses(batches, responses, before)
        self.assertEqual(before, workflow.snapshot())

    def test_missing_duplicate_extra_and_malformed_responses_are_rejected(self):
        self.change_source()
        workflow = self.workflow()
        batch = workflow.batches(["es"], 20)[0]
        item = self.response(batch)["translations"][0]
        for response in [{"translations": []}, {"translations": [item, item]},
                         {"translations": [{**item, "key": "extra"}]}, {"translations": "wrong"}]:
            response["batch_id"] = l10n.digest(batch["payload"])
            with self.subTest(response=response), self.assertRaises(l10n.L10nError):
                workflow.validate_response(batch, response)

    def test_stale_bundle_does_not_overwrite_newer_source(self):
        self.change_source()
        workflow = self.workflow()
        batches = workflow.batches(["es"], 20)
        before = workflow.snapshot()
        self.change_source(text="Save all edits")
        with self.assertRaisesRegex(l10n.L10nError, "changed while translating"):
            workflow.apply_responses(batches, [self.response(batches[0])], before)

    def test_prepare_and_offline_import_use_the_same_trusted_inputs(self):
        self.change_source()
        workflow = self.workflow()
        directory = self.root / "bundle"
        batches = workflow.batches(["es", "ja"], 20)
        workflow.prepare(directory, batches)
        before = workflow.snapshot()
        self.assertIn("Latin America", (directory / "es-001.prompt.txt").read_text())
        self.assertEqual(before, workflow.snapshot())
        for batch in batches:
            self.save(directory / batch["name"], self.response(batch, "保存" if batch["payload"]["language"] == "ja" else "Guardar cambios"))
        result = l10n.main(["--root", str(self.root), "translate", "--responses-dir", str(directory)])
        self.assertEqual(result, 0)
        self.workflow().check()

    def test_deleted_source_keys_are_pruned_without_model_invocation(self):
        self.source.pop("greeting")
        self.source.pop("@greeting")
        self.save(self.arb_dir / "app_en.arb", self.source)
        workflow = self.workflow()
        workflow.apply_responses([], [], workflow.snapshot())
        after = self.workflow()
        after.check()
        self.assertNotIn("greeting", after.catalogs["es"])
        self.assertNotIn("greeting", after.state["languages"]["es"]["entries"])

    def test_codex_adapter_supplies_schema_stdin_and_readonly_isolated_workspace(self):
        self.change_source()
        workflow = self.workflow()
        batch = workflow.batches(["es"], 20)[0]
        executable = self.root / "fake-codex"
        executable.write_text("#!" + sys.executable + "\n" + """
import json, pathlib, sys
args = sys.argv[1:]
assert args[0] == 'exec'
assert args[args.index('--sandbox') + 1] == 'read-only'
assert '--ignore-user-config' in args and '--ephemeral' in args
workspace = pathlib.Path(args[args.index('--cd') + 1])
assert not (workspace / 'AGENTS.md').exists()
prompt = sys.stdin.read()
assert 'Guardar' in prompt and 'previous_translation' in prompt
schema = json.loads(pathlib.Path(args[args.index('--output-schema') + 1]).read_text())
keys = schema['properties']['translations']['items']['properties']['key']['enum']
result = {'batch_id': schema['properties']['batch_id']['enum'][0], 'translations': [{'key': key, 'text': 'Guardar cambios', 'status': 'translated', 'note': ''} for key in keys]}
pathlib.Path(args[args.index('--output-last-message') + 1]).write_text(json.dumps(result))
""")
        executable.chmod(0o755)
        response = l10n.run_codex(workflow, batch, str(executable), 10)
        self.assertEqual(workflow.validate_response(batch, response)["saveAction"]["text"], "Guardar cambios")

    def test_missing_executor_is_an_explicit_failure(self):
        self.change_source()
        workflow = self.workflow()
        with self.assertRaisesRegex(l10n.L10nError, "unavailable"):
            l10n.run_codex(workflow, workflow.batches(["es"], 20)[0], "/nonexistent/codex", 1)

    def test_duplicate_arb_keys_are_rejected(self):
        (self.arb_dir / "app_es.arb").write_text('{"saveAction":"A","saveAction":"B"}')
        with self.assertRaisesRegex(l10n.L10nError, "duplicate JSON key"):
            self.workflow()

    def test_reused_bundle_directory_and_old_batch_output_are_rejected(self):
        self.change_source()
        workflow = self.workflow()
        batches = workflow.batches(["es"], 20)
        directory = self.root / "bundle"
        workflow.prepare(directory, batches)
        with self.assertRaisesRegex(l10n.L10nError, "must be empty"):
            workflow.prepare(directory, batches)
        response = self.response(batches[0])
        response["batch_id"] = "old"
        with self.assertRaisesRegex(l10n.L10nError, "different source batch"):
            workflow.validate_response(batches[0], response)


class IcuTests(unittest.TestCase):
    def validate(self, source, target, placeholders, policy="inflected", glossary=None):
        l10n.validate_message("message", target, source, {"placeholders": placeholders},
                              {"plural_policy": policy}, glossary or {})

    def test_nested_icu_and_quoted_literal_markers(self):
        source = "{gender, select, male{{count, plural, =1{1 item} other{{count} items}}} other{{count} items}}"
        target = "{gender, select, male{{count, plural, =0{{count} cosas} =1{1 cosa} other{{count} cosas}}} other{{count} cosas}}"
        self.validate(source, target, {"gender": {}, "count": {}})
        self.validate("'{{user}}'", "'{{user}}'", {}, glossary={"literal_markers": {"message": ["{{user}}"]}})

    def test_parameter_loss_unknown_parameter_and_branch_loss(self):
        for target in ["Hola", "Hola {other}", "Hola {name} {extra}"]:
            with self.subTest(target=target), self.assertRaises(l10n.L10nError):
                self.validate("Hello {name}", target, {"name": {}})
        with self.assertRaisesRegex(l10n.L10nError, "loses a branch"):
            self.validate("{count, plural, =1{1 item} other{{count} items}}",
                          "{count, plural, =0{{count} cosas} =1{1 cosa} other{cosas}}", {"count": {}})

    def test_invalid_braces_quotes_and_missing_other(self):
        for text in ["{name", "{name}}", "It's fine", "{n, plural, =1{one}}", "{n, plural, other{x} other{y}}"]:
            with self.subTest(text=text), self.assertRaises(l10n.L10nError):
                l10n.IcuParser(text).parse()
        l10n.IcuParser("It''s '{Example}' and {name}").parse()

    def test_zero_branch_is_required_for_inflected_count_message(self):
        with self.assertRaisesRegex(l10n.L10nError, "explicit =0"):
            self.validate("{count, plural, =1{1 day} other{{count} days}}",
                          "{count, plural, =1{1 día} other{{count} días}}", {"count": {}})
        self.validate("{count, plural, =1{1 day} other{{count} days}}", "{count}日", {"count": {}}, "uninflected")

    def test_select_conditions_cannot_be_flattened(self):
        with self.assertRaisesRegex(l10n.L10nError, "missing select"):
            self.validate("{mode, select, on{On} other{Off}}", "{mode}", {"mode": {}}, "uninflected")

    def test_brand_names_cannot_be_translated(self):
        with self.assertRaisesRegex(l10n.L10nError, "Worldo"):
            self.validate("Open Worldo", "Abrir mundo", {}, glossary={"preserve": ["Worldo"]})


if __name__ == "__main__":
    unittest.main()
