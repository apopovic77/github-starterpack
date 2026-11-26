"""Tests für prod-pakete-sammler (#4064). Laufen ohne ssh: die Fernabfrage wird ersetzt."""
import importlib.machinery
import importlib.util
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest

HIER = Path(__file__).resolve().parent.parent
_l = importlib.machinery.SourceFileLoader("sammler", str(HIER / "prod-pakete-sammler"))
_s = importlib.util.spec_from_loader("sammler", _l)
sammler = importlib.util.module_from_spec(_s)
_l.exec_module(sammler)

# studio-test als Leser, damit die geschriebene Datei gegen dessen echte Prüfung läuft
_l2 = importlib.machinery.SourceFileLoader("studio_test", str(HIER / "studio-test"))
_s2 = importlib.util.spec_from_loader("studio_test", _l2)
studio_test = importlib.util.module_from_spec(_s2)
_l2.exec_module(studio_test)

KERN = {
    "hosts": {"arkserver": {"ssh": ["ssh", "-n", "root@a"]}, "arkturian": {"ssh": ["ssh", "-n", "root@b"]}},
    "dienste": {
        "cloud-api": {"host": "arkserver", "unit": "cloud-api", "dir": "/var/www/cloud-api/backend"},
        "auth-api": {"host": "arkturian", "unit": "auth-api", "dir": "/var/www/auth-api"},
        "mcp-server": {"host": "arkturian", "unit": "mcp-server", "dir": "/var/www/mcp.arkturian.com"},
    },
}

ANTWORT = {
    ("root@a", "cloud-api"): {"venv": "/var/www/cloud-api/venv", "wie": "argv", "pid": 1, "python": "3.11",
                              "pakete": ["fastapi==0.141.1", "starlette==1.6.0"], "repo": "cloud-api"},
    ("root@b", "auth-api"): {"venv": "/var/www/auth-api/.venv", "wie": "argv", "pid": 2, "python": "3.11",
                             "pakete": ["fastapi==0.136.1", "starlette==1.0.0", "-e git+x==1"], "repo": ""},
    ("root@b", "mcp-server"): {"kein_python": True, "fehler": "kein venv am Prozess (node)"},
}


def fake_lauf(antworten):
    def lauf(cmd, **kw):
        host = next(c for c in cmd if c.startswith("root@"))
        unit = cmd[-2].strip("'")
        a = antworten.get((host, unit))
        if a is None:
            return subprocess.CompletedProcess(cmd, 255, "", "ssh: connect failed")
        return subprocess.CompletedProcess(cmd, 0, "motd\n" + json.dumps(a) + "\n", "")
    return lauf


def test_schreibt_je_dienst_und_ueberspringt_node(tmp_path):
    out = []
    rc = sammler.sammeln(KERN, tmp_path, lauf=fake_lauf(ANTWORT), ausgabe=out.append)
    assert rc == 0
    assert sorted(p.name for p in tmp_path.iterdir()) == ["auth-api.json", "cloud-api.json"]
    a = json.loads((tmp_path / "auth-api.json").read_text())
    assert a["quelle"] == {"host": "arkturian", "unit": "auth-api.service", "venv": "/var/www/auth-api/.venv"}
    assert a["pakete"] == ["fastapi==0.136.1", "starlette==1.0.0"]          # ungültige Zeile fällt weg
    assert oct((tmp_path / "auth-api.json").stat().st_mode & 0o777) == "0o644"
    assert any("mcp-server: kein Python-Dienst" in z for z in out)
    assert any("1 Zeilen ausgelassen" in z for z in out)


def test_gegenprobe_studio_test_liest_die_datei(tmp_path, monkeypatch):
    """auth-api bekommt die Stände von arkturian, cloud-api die vom Kern, gelesen mit der echten Prüfung."""
    sammler.sammeln(KERN, tmp_path, lauf=fake_lauf(ANTWORT), ausgabe=lambda z: None)
    monkeypatch.setattr(studio_test, "PROD_PAKETE", tmp_path)
    a = studio_test.prod_pakete("auth-api")
    c = studio_test.prod_pakete("cloud-api")
    assert "fastapi==0.136.1" in a["pakete"] and a["quelle"].startswith("arkturian:/var/www/auth-api/.venv")
    assert "fastapi==0.141.1" in c["pakete"] and c["quelle"].startswith("arkserver:/var/www/cloud-api/venv")


def test_fehler_laesst_alte_datei_stehen(tmp_path):
    alt = tmp_path / "auth-api.json"
    tmp_path.mkdir(exist_ok=True)
    alt.write_text('{"alt": true}')
    antworten = {k: v for k, v in ANTWORT.items() if k[1] != "auth-api"}
    out = []
    rc = sammler.sammeln(KERN, tmp_path, lauf=fake_lauf(antworten), ausgabe=out.append)
    assert rc == 1
    assert alt.read_text() == '{"alt": true}'
    assert any("auth-api: kein Stand, alte Datei bleibt" in z for z in out)


def test_gegenprobe_fehler_ohne_fehlerfall_rc0(tmp_path):
    assert sammler.sammeln(KERN, tmp_path, lauf=fake_lauf(ANTWORT), ausgabe=lambda z: None) == 0


def test_mehrere_rechner_aeltester_gewinnt_abweichung_steht_drin(tmp_path):
    kern = {"hosts": KERN["hosts"],
            "dienste": {"auth-api": {"hosts": ["arkserver", "arkturian"], "unit": "auth-api",
                                     "dir": "/var/www/auth-api"}}}
    antworten = {
        ("root@a", "auth-api"): {"venv": "/var/www/auth-api/venv", "python": "3.11", "repo": "auth-api",
                                 "pakete": ["fastapi==0.141.1", "starlette==1.6.0", "pydantic==2.10.0"]},
        ("root@b", "auth-api"): {"venv": "/var/www/auth-api/.venv", "python": "3.11", "repo": "auth-api",
                                 "pakete": ["fastapi==0.136.1", "starlette==1.0.0", "pydantic==2.10.0"]},
    }
    sammler.sammeln(kern, tmp_path, lauf=fake_lauf(antworten), ausgabe=lambda z: None)
    d = json.loads((tmp_path / "auth-api.json").read_text())
    assert d["quelle"]["host"] == "arkturian"
    assert d["abweichung"] == [{"host": "arkserver", "venv": "/var/www/auth-api/venv", "python": "3.11",
                                "anders": ["fastapi==0.141.1", "starlette==1.6.0"]}]


def test_aeltester_reihenfolge_ist_egal():
    neu = {"host": "x", "venv": "/v", "python": "3.11", "pakete": ["a==2.0", "b==1.10"]}
    alt = {"host": "y", "venv": "/w", "python": "3.11", "pakete": ["a==1.9", "b==1.9"]}
    assert sammler.aeltester([neu, alt]) == 1
    assert sammler.aeltester([alt, neu]) == 0


def test_kleinere_python_version_ist_aelter():
    a = {"host": "x", "venv": "/v", "python": "3.12", "pakete": ["a==1.0"]}
    b = {"host": "y", "venv": "/w", "python": "3.11", "pakete": ["a==9.0"]}
    assert sammler.aeltester([a, b]) == 1


def test_versionsvergleich_numerisch():
    assert sammler.version_schluessel("1.10.0") > sammler.version_schluessel("1.9.3")


def test_stand_ist_iso_mit_zeitzone():
    d = sammler.datei_bauen("x", "x.service", [{"host": "h", "venv": "/v", "python": "3.11", "pakete": ["a==1"]}],
                            jetzt=datetime(2026, 11, 26, 10, 0, tzinfo=timezone.utc))
    assert d["stand"] == "2026-11-26T10:00:00Z" and d["quelle"]["unit"] == "x.service"


def test_kern_eintrag_mit_unsicherem_namen_wird_nicht_abgefragt(tmp_path):
    kern = {"hosts": KERN["hosts"],
            "dienste": {"boese": {"host": "arkserver", "unit": "x; rm -rf /", "dir": "/var/www/x"}}}
    aufrufe = []

    def lauf(cmd, **kw):
        aufrufe.append(cmd)
        raise AssertionError("darf nicht laufen")
    assert sammler.sammeln(kern, tmp_path, lauf=lauf, ausgabe=lambda z: None) == 1
    assert aufrufe == []


def test_fern_befehl_quotet_jedes_argument():
    cmd = sammler.fern_befehl(["ssh", "-n", "root@a"], "auth-api", "/var/www/auth-api")
    assert cmd[:3] == ["ssh", "-n", "root@a"]
    assert cmd[3:6] == ["python3", "-I", "-c"]
    assert cmd[6].startswith("'import base64;exec(") and cmd[-1] == "/var/www/auth-api"


def test_fernskript_ist_gueltiges_python():
    compile(sammler.FERN, "fern", "exec")


def test_trocken_schreibt_nichts(tmp_path):
    out = []
    sammler.sammeln(KERN, tmp_path / "z", trocken=True, lauf=fake_lauf(ANTWORT), ausgabe=out.append)
    assert not (tmp_path / "z").exists()
    assert any(z.startswith("trocken: auth-api -> auth-api.json: arkturian") for z in out)


def test_eigener_rechner_ohne_ssh(tmp_path):
    gesehen = []

    def lauf(cmd, **kw):
        gesehen.append(cmd)
        if cmd[0] == "ssh":
            return fake_lauf(ANTWORT)(cmd)
        assert cmd[:3] == ["python3", "-I", "-c"] and cmd[-2:] == ["cloud-api", "/var/www/cloud-api/backend"]
        return subprocess.CompletedProcess(cmd, 0, json.dumps(ANTWORT[("root@a", "cloud-api")]) + "\n", "")
    assert sammler.sammeln(KERN, tmp_path, lauf=lauf, ausgabe=lambda z: None, lokal="arkserver") == 0
    assert [c[0] for c in gesehen] == ["python3", "ssh", "ssh"]
    # Gegenprobe: ohne lokal geht auch der eigene Rechner über ssh
    gesehen.clear()
    sammler.sammeln(KERN, tmp_path, lauf=fake_lauf(ANTWORT), ausgabe=lambda z: None)
