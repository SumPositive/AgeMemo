#!/usr/bin/env python3
# MoonPhase の黄経差と輝面率を、1600〜2100年の全日について DE440 と比べる
#
# アプリの Swift のコード（LunarDate・LunarMonthTable・MoonPhase）をそのままコンパイルして全日の値を出させ、
# skyfield と NASA JPL の DE440 で求めた日本時間正午の値と突き合わせる。式を Python で書き直さないので、
# アプリの実装そのものを検証できる。LunarCalendarTests は代表日だけを見るので、全期間はこのスクリプトで保証する
#
# 使い方: pip install skyfield のあと python3 Scripts/verify_moon_phase.py <de440.bsp を置くフォルダ>
# de440.bsp（約120MB）が無ければそのフォルダへ自動で取得する。swiftc（Xcode）が必要
# 黄経差の誤差が0.1度以上、または輝面率の差が1%以上の日があれば終了コード1で終わる

import datetime as dt
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from skyfield.api import Loader
from skyfield.framelib import ecliptic_frame

FIRST_YEAR, LAST_YEAR = 1600, 2100
ELONGATION_LIMIT = 0.1  # 度
ILLUMINATION_LIMIT = 0.01  # 輝面率（0〜1）
CORE = Path(__file__).resolve().parent.parent / "AgeMemo/Core"
SOURCES = ["LunarDate.swift", "LunarMonthTable.swift", "MoonPhase.swift"]

# 全日の黄経差と輝面率を書き出す Swift の本体
DRIVER = f"""
func daysIn(year: Int, month: Int) -> Int {{
    let isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    return [31, isLeapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
}}
var lines: [String] = []
for year in {FIRST_YEAR}...{LAST_YEAR} {{
    for month in 1...12 {{
        for day in 1...daysIn(year: year, month: month) {{
            guard let moon = MoonPhase(year: year, month: month, day: day) else {{
                fatalError("\\(year)-\\(month)-\\(day) が表の範囲外")
            }}
            lines.append("\\(year) \\(month) \\(day) \\(moon.elongation) \\(moon.illumination)")
        }}
    }}
}}
print(lines.joined(separator: "\\n"))
"""


def app_values():
    with tempfile.TemporaryDirectory() as work:
        work = Path(work)
        (work / "main.swift").write_text(DRIVER)
        executable = work / "moon"
        subprocess.run(
            ["xcrun", "swiftc", "-O", str(work / "main.swift"), *[str(CORE / name) for name in SOURCES],
             "-o", str(executable)],
            check=True,
        )
        output = subprocess.run([str(executable)], check=True, capture_output=True, text=True).stdout
    rows = [line.split() for line in output.splitlines()]
    dates = [dt.date(int(y), int(m), int(d)) for y, m, d, _, _ in rows]
    elongations = np.array([float(row[3]) for row in rows])
    illuminations = np.array([float(row[4]) for row in rows])
    return dates, elongations, illuminations


def main():
    loader = Loader(sys.argv[1] if 1 < len(sys.argv) else ".")
    ts = loader.timescale()
    eph = loader("de440.bsp")
    earth, moon, sun = eph["earth"], eph["moon"], eph["sun"]

    dates, app_elongations, app_illuminations = app_values()
    print(f"{len(dates)} 日を比べる（{dates[0]} 〜 {dates[-1]}、日本時間の正午）")

    # 日本時間の正午は世界時の3時
    t = ts.utc([d.year for d in dates], [d.month for d in dates], [d.day for d in dates], 3)
    position = earth.at(t)
    _, moon_longitude, _ = position.observe(moon).apparent().frame_latlon(ecliptic_frame)
    _, sun_longitude, _ = position.observe(sun).apparent().frame_latlon(ecliptic_frame)
    reference_elongations = (moon_longitude.degrees - sun_longitude.degrees) % 360
    reference_illuminations = position.observe(moon).apparent().fraction_illuminated(sun)

    # 0度と360度をまたぐ差は折り返す
    elongation_errors = np.abs((app_elongations - reference_elongations + 180) % 360 - 180)
    illumination_errors = np.abs(app_illuminations - reference_illuminations)

    worst = int(np.argmax(elongation_errors))
    print(f"黄経差の誤差: 最大 {elongation_errors.max():.4f} 度（{dates[worst]}）、平均 {elongation_errors.mean():.4f} 度")
    worst = int(np.argmax(illumination_errors))
    print(f"輝面率の差: 最大 {illumination_errors.max() * 100:.3f} ポイント（{dates[worst]}）")

    failed = (ELONGATION_LIMIT <= elongation_errors) | (ILLUMINATION_LIMIT <= illumination_errors)
    if failed.any():
        for index in np.flatnonzero(failed)[:20]:
            print(f"超過: {dates[index]} 黄経差 {elongation_errors[index]:.4f} 度、輝面率 {illumination_errors[index] * 100:.3f} ポイント")
        print(f"基準を超えた日: {int(failed.sum())} 日")
        sys.exit(1)
    print(f"全日で黄経差の誤差 {ELONGATION_LIMIT} 度未満、輝面率の差 {ILLUMINATION_LIMIT * 100:.0f}% 未満")


if __name__ == "__main__":
    main()
