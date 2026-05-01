import os
import sys
import unittest


THIS_DIR = os.path.dirname(__file__)
PROJECT_ROOT = os.path.abspath(os.path.join(THIS_DIR, ".."))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

import bms_parser  # noqa: E402


class ParserContractTests(unittest.TestCase):
    def test_pdf_import_error_returns_warning_list(self):
        original = __import__

        def fake_import(name, *args, **kwargs):
            if name == "pdfplumber":
                raise ImportError("mocked missing dependency")
            return original(name, *args, **kwargs)

        import builtins

        builtins_import = builtins.__import__
        builtins.__import__ = fake_import
        try:
            text, warnings = bms_parser.extract_text_from_pdf(b"not_a_real_pdf")
            self.assertEqual(text, "")
            self.assertIsInstance(warnings, list)
            self.assertIn("pdfplumber not installed", warnings)
        finally:
            builtins.__import__ = builtins_import

    def test_student_parser_normalises_basic_row(self):
        row = {"USN": "1bm 25mca001", "Name": "john doe", "Programme": "MCA"}
        parsed = bms_parser._normalise_student_row(row)
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed["usn"], "1BM 25MCA001".replace(" ", ""))
        self.assertEqual(parsed["name"], "John Doe")
        self.assertEqual(parsed["programme"], "MCA")


if __name__ == "__main__":
    unittest.main()
