#!/usr/bin/env python3
# 日本の旧暦の月初めと満月の日の表（AgeMemo/Core/LunarMonthTable.swift）を書き出す
#
# 現行の旧暦の決め方（天保暦の置閏法を定気・日本時間で当てはめたもの）に従う
# - 朔（新月）を含む日本時間の日を月の1日とする
# - 冬至を含む月を11月とし、冬至から冬至までに13か月あれば中気を含まない最初の月を閏月とする
# - 2033年問題は、日本カレンダー暦文化振興協会の推奨と同じ閏11月になる
# - 1600年まで同じ方式で遡る。1843年以前に実際に使われた暦（宣明暦・貞享暦・宝暦暦・寛政暦）とは違い、参考値になる
# - 満月は、望（満月の瞬間）を含む日本時間の日とする。一般的なカレンダーの満月の日と同じ
#
# 天体位置は NASA JPL の DE440、ΔT（地球の自転の遅れ）は skyfield の値を使う
# ephem は将来の ΔT を大きく見積もり、2074年・2097年の朔が日付をまたいでずれたので使わない
#
# 使い方: pip install skyfield のあと python3 Scripts/gen_lunar_month_table.py <de440.bsp を置くフォルダ>
# de440.bsp（約120MB）が無ければそのフォルダへ自動で取得する
# 朔や中気が日付の変わり目に近いと ΔT の誤差で結果が変わりうるので、標準エラーに一覧を出す

import datetime as dt
import sys
from pathlib import Path

from skyfield import almanac
from skyfield.api import Loader
from skyfield.framelib import ecliptic_frame

FIRST_YEAR, LAST_YEAR = 1600, 2100
JST = dt.timedelta(hours=9)
NEAR_MIDNIGHT = dt.timedelta(minutes=5)
OUTPUT = Path(__file__).resolve().parent.parent / "AgeMemo/Core/LunarMonthTable.swift"


def to_jst(t):
    return t.utc_datetime().replace(tzinfo=None) + JST


def is_near_midnight(local):
    since = local - local.replace(hour=0, minute=0, second=0, microsecond=0)
    return since < NEAR_MIDNIGHT or dt.timedelta(days=1) - since < NEAR_MIDNIGHT


def warn(label, local):
    print(f"日付の変わり目に近い{label}: {local:%Y-%m-%d %H:%M:%S} JST", file=sys.stderr)


def main():
    loader = Loader(sys.argv[1] if 1 < len(sys.argv) else ".")
    ts = loader.timescale()
    eph = loader("de440.bsp")
    start = ts.utc(FIRST_YEAR - 2, 10, 1)
    end = ts.utc(LAST_YEAR + 2, 3, 1)

    times, phases = almanac.find_discrete(start, end, almanac.moon_phases(eph))
    new_moons = []
    full_moons = []
    for t, phase in zip(times, phases):
        # 0が朔、2が望
        if phase not in (0, 2):
            continue
        local = to_jst(t)
        if is_near_midnight(local):
            warn("朔" if phase == 0 else "望", local)
        (new_moons if phase == 0 else full_moons).append(local.date())

    # 中気は太陽黄経が30度の倍数になる時。冬至は270度
    earth, sun = eph["earth"], eph["sun"]

    def principal_term_index(t):
        _, lon, _ = earth.at(t).observe(sun).apparent().frame_latlon(ecliptic_frame)
        return (lon.degrees // 30).astype(int)

    principal_term_index.step_days = 20
    times, indices = almanac.find_discrete(start, end, principal_term_index)
    terms = []
    for t, index in zip(times, indices):
        local = to_jst(t)
        longitude = int(index) * 30 % 360
        # 中気は朔の日の前後にあるときだけ、どの月に入るかが変わりうる
        if is_near_midnight(local) and any(abs((local.date() - day).days) <= 1 for day in new_moons):
            warn(f"中気({longitude}度)", local)
        terms.append((local.date(), longitude))

    months = []
    for first, next_first in zip(new_moons, new_moons[1:]):
        contained = [lon for day, lon in terms if first <= day < next_first]
        full_moon_day = next((day - first).days + 1 for day in full_moons if first <= day < next_first)
        months.append((first, contained, full_moon_day))

    solstice_indices = [i for i, (_, contained, _) in enumerate(months) if 270 in contained]
    starts = []
    for begin, finish in zip(solstice_indices, solstice_indices[1:]):
        span = months[begin:finish]
        has_leap = len(span) == 13
        number, leap_used = 11, False
        for index, (first, contained, full_moon_day) in enumerate(span):
            if 0 < index:
                if has_leap and not leap_used and not contained:
                    leap_used = True
                else:
                    number = number % 12 + 1
            starts.append((first, number, full_moon_day))

    # 表の最初の月は FIRST_YEAR の元日を含む月にする。最後の月は終わりを示すため翌月まで入れる
    first_index = max(i for i, (day, _, _) in enumerate(starts) if day <= dt.date(FIRST_YEAR, 1, 1))
    last_index = max(i for i, (day, _, _) in enumerate(starts) if day <= dt.date(LAST_YEAR, 12, 31))
    rows = [f"{day:%Y%m%d}{month:02d}{full:02d}" for day, month, full in starts[first_index:last_index + 2]]

    lines = [", ".join(rows[i:i + 5]) + "," for i in range(0, len(rows), 5)]
    body = "\n".join("        " + line for line in lines)
    OUTPUT.write_text(f"""// 日本の旧暦の月初めと満月の日の表。Scripts/gen_lunar_month_table.py で生成するので手で編集しない

enum LunarMonthTable {{
    /// 旧暦の各月の1日（西暦の年月日）、月の番号、満月にあたる旧暦の日を YYYYMMDDmmff の形で並べたもの。
    /// 閏月は元の月と同じ番号になる
    static let starts: [Int] = [
{body}
    ]
}}
""")
    print(f"{len(rows)} か月分を書き出した: {OUTPUT}", file=sys.stderr)


if __name__ == "__main__":
    main()
