"""Tests for check_id_order.py: each fault it names is caught, and naming an id is not."""
import unittest

from check_id_order import violations_in


def reasons(code: str) -> list:
    return [why for _, why in violations_in(code)]


class CheckIdOrderTest(unittest.TestCase):
    def test_comparing_ids_by_order_is_caught(self):
        self.assertEqual(reasons("\treturn a.id < b.id"), ["id compared by order"])
        self.assertEqual(reasons("\tif a[1].id > 3:"), ["id compared by order"])

    def test_arithmetic_on_an_id_is_caught(self):
        self.assertEqual(reasons("\treturn x * 4096 + unit.id % 4096"), ["arithmetic on an id"])

    def test_an_id_in_a_key_is_caught(self):
        self.assertEqual(reasons("\tvar key := [front, gap, other.id]"), ["id in a key"])

    def test_sorting_ids_is_caught(self):
        self.assertEqual(reasons("\tids.sort()"), ["ids sorted"])

    def test_naming_an_id_is_fine(self):
        for code in [
            "\tvar entry: Dictionary = squad.loose[unit.id]",
            "\tif friend.id == entry.get(\"held_by\"):",
            "\tunit.target_id = target.id",
            "\tvar extra := {\"unit\": router.id}",
            "\tvar gap := where(squad, unit.id)",
        ]:
            self.assertEqual(reasons(code), [], code)

    def test_salting_a_seeded_draw_is_fine(self):
        self.assertEqual(reasons("\tvar roll := posmod(hash([seed, tick, unit.id]), 11)"), [])
        self.assertEqual(reasons("\tBattleRolls.damage(d, band, seed, [tick, shot[0].id, 1])"), [])

    def test_comments_are_ignored(self):
        self.assertEqual(reasons("\tpass  # never a.id < b.id"), [])

    def test_a_reasoned_allowance_passes(self):
        self.assertEqual(reasons("\tids.sort()  # id-order-ok: orders only the log"), [])
        self.assertEqual(reasons("\t# id-order-ok: orders only the log\n\tids.sort()"), [])
        self.assertEqual(reasons("\tids.sort()  # id-order-ok:"), ["ids sorted"])


if __name__ == "__main__":
    unittest.main()
