class_name BackendGrader
extends Node

## Forwards a completed candidate session to the FastAPI grading backend and returns the
## deterministic score. The backend scores off the event log, so we replay the candidate's
## recorded events, then submit the frozen-vocabulary decision, then read the Proof Replay.
##
## Usage (async):  var result := await grader.grade(base_url, email, events, submission, scenario)
## Returns { ok:bool, error:String, total:float, max:float, criteria:Array, report:Dictionary }.
## Fully graceful: any failed step returns { ok=false, error } so the caller keeps the local summary.

var _http: HTTPRequest

func _ensure_http() -> void:
	if _http == null:
		_http = HTTPRequest.new()
		add_child(_http)

func grade(base_url: String, email: String, events: Array, submission: Dictionary, scenario: Dictionary) -> Dictionary:
	_ensure_http()
	base_url = base_url.strip_edges().trim_suffix("/")
	if base_url.is_empty():
		return {"ok": false, "error": "no backend url"}

	# 1. create a grading session
	var created := await _req(HTTPClient.METHOD_POST, base_url + "/api/sessions",
		{"display_name": email if not email.is_empty() else "candidate"})
	if not created.ok:
		return {"ok": false, "error": "create session: " + str(created.error)}
	var sid := str(created.body.get("session_id", ""))
	if sid.is_empty():
		return {"ok": false, "error": "backend returned no session_id"}

	# 2. replay the candidate's frontend events (evidence, hypotheses, AI disposition, decision)
	for ev: Variant in events:
		var mapped := _map_event(ev)
		if not mapped.is_empty():
			await _req(HTTPClient.METHOD_POST, "%s/api/sessions/%s/events" % [base_url, sid], mapped)

	# 3. replay verification tests (recorded backend-side via the workspace test endpoint)
	for ev: Variant in events:
		if str((ev as Dictionary).get("event_type", "")) == "test_executed":
			var p: Dictionary = (ev as Dictionary).get("payload", {})
			await _req(HTTPClient.METHOD_POST, "%s/api/sessions/%s/tests/%s" % [base_url, sid, str(p.get("test_id", ""))],
				{"remediation_id": str(p.get("remediation_id", ""))})

	# 4. submit the frozen-vocabulary decision (triggers grading)
	var sub := await _req(HTTPClient.METHOD_POST, "%s/api/sessions/%s/submit" % [base_url, sid],
		_submit_body(submission, scenario))
	if not sub.ok:
		return {"ok": false, "error": "submit: " + str(sub.error)}

	# 5. read the graded Proof Replay
	var rep := await _req(HTTPClient.METHOD_GET, "%s/api/sessions/%s/report" % [base_url, sid], {})
	if not rep.ok:
		return {"ok": false, "error": "report: " + str(rep.error)}
	var det: Dictionary = (rep.body.get("scores", {}) as Dictionary).get("deterministic", {})
	return {
		"ok": true,
		"session_id": sid,
		"total": float(det.get("total", 0.0)),
		"max": float(det.get("max", 0.0)),
		"criteria": det.get("criteria", []),
		"report": rep.body,
	}

func _req(method: int, url: String, body: Dictionary) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var data := "" if (method == HTTPClient.METHOD_GET) else JSON.stringify(body)
	var err := _http.request(url, headers, method, data)
	if err != OK:
		return {"ok": false, "error": "request() error %d" % err}
	var res: Array = await _http.request_completed
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	var body_dict: Dictionary = parsed if parsed is Dictionary else {}
	if code >= 200 and code < 300:
		return {"ok": true, "code": code, "body": body_dict}
	return {"ok": false, "code": code, "error": "HTTP %d %s" % [code, text.substr(0, 200)], "body": body_dict}

func _map_event(ev_v: Variant) -> Dictionary:
	var ev: Dictionary = ev_v
	var t := str(ev.get("event_type", ""))
	var p: Dictionary = ev.get("payload", {})
	match t:
		"evidence_viewed":
			return {"event_type": t, "payload": {"artifact_id": str(p.get("artifact_id", ""))}}
		"hypothesis_recorded":
			return {"event_type": t, "payload": {
				"version": int(p.get("version", 1)),
				"hypothesis_id": str(p.get("hypothesis_id", "")),
				"confidence": int(p.get("confidence", 50)),
				"trigger_evidence_ids": [],
			}}
		"hypothesis_revised":
			var triggers: Array = []
			for f: Variant in p.get("trigger_fact_ids", []):
				triggers.append(str(f))
			return {"event_type": t, "payload": {
				"previous_version": max(1, int(p.get("version", 2)) - 1),
				"version": int(p.get("version", 2)),
				"hypothesis_id": str(p.get("hypothesis_id", "")),
				"confidence": int(p.get("confidence", 50)),
				"trigger_evidence_ids": triggers,
			}}
		"ai_suggestion_dispositioned":
			return {"event_type": t, "payload": {
				"response_id": str(p.get("response_id", "")),
				"option_id": str(p.get("option_id", "")),
			}}
		"decision_recorded":
			var rationale := str(p.get("rationale", ""))
			return {"event_type": t, "payload": {
				"action": "propose_remediation:" + str(p.get("remediation_id", "")),
				"rationale": rationale if not rationale.is_empty() else "final decision submitted",
			}}
		_:
			return {}

func _submit_body(s: Dictionary, scenario: Dictionary) -> Dictionary:
	var impact := str(s.get("expected_impact_id", ""))
	if impact.is_empty():
		var opts: Dictionary = scenario.get("submission_options", {})
		var impacts: Array = opts.get("expected_impacts", scenario.get("expected_impacts", []))
		if not impacts.is_empty():
			impact = str((impacts[0] as Dictionary).get("option_id", ""))
	var ev_ids: Array = []
	for e: Variant in s.get("evidence_ids", []):
		ev_ids.append(str(e))
	return {
		"root_cause_id": str(s.get("root_cause_id", "")),
		"supporting_evidence_ids": ev_ids,
		"remediation_id": str(s.get("remediation_id", "")),
		"expected_impact_id": impact,
		"risk_ids": s.get("risk_ids", []),
		"assumption_ids": s.get("assumption_ids", []),
		"validation_test_ids": s.get("validation_test_ids", []),
		"rollback_id": str(s.get("rollback_id", "")),
		"final_confidence": int(s.get("final_confidence", 50)),
		"rationale": str(s.get("rationale", "")),
	}
