#!/usr/bin/python
"""$Id: testXmlEncodingDecode.py 511 2006-03-07 05:19:10Z rubys $"""

__author__ = "Joseph Walton <http://www.kafsemo.org/>"
__version__ = "$Revision: 511 $"
__date__ = "$Date: 2006-03-07 18:19:10 +1300 (Tue, 07 Mar 2006) $"
__copyright__ = "Copyright (c) 2004 Joseph Walton"
__license__ = "Python"

import os, sys

curdir = os.path.abspath(os.path.dirname(sys.argv[0]))
srcdir = os.path.split(curdir)[0]
if srcdir not in sys.path:
  sys.path.insert(0, srcdir)
basedir = os.path.split(srcdir)[0]

import unittest
from feedvalidator import xmlEncoding
from feedvalidator.logging import *

ctAX='application/xml'

class TestDecode(unittest.TestCase):
  def _assertEqualUnicode(self, a, b):
    self.assertNotEqual(a, None, 'Decoded strings should not equal None')
    self.assertEqual(type(a), unicode, 'Decoded strings should be Unicode')
    self.assertEqual(type(b), unicode, 'Test suite error: test strings must be Unicode')
    self.assertEqual(a, b)

  def testProvidedEncoding(self):
    loggedEvents=[]
    self._assertEqualUnicode(xmlEncoding.decode(ctAX, 'UTF-8', '<x/>', loggedEvents), u'<x/>')
    self.assertEqual(loggedEvents, [])

    loggedEvents=[]
    self._assertEqualUnicode(xmlEncoding.decode(ctAX, 'UTF-8', '<?xml version="1.0" encoding="utf-8"?><x/>', loggedEvents), u'<?xml version="1.0" encoding="utf-8"?><x/>')
    self.assertEquals(loggedEvents, [])

  def testNoDeclarationOrBOM(self):
    loggedEvents=[]
    self.assertEquals(xmlEncoding.decode(ctAX, None, '<x/>', loggedEvents), None)
    self.assertEquals(len(loggedEvents), 1)
    self.assertEquals(loggedEvents[0].__class__, MissingEncoding, "Must warn if there's no clue as to encoding")

# This document is currently detected as UTF-8, rather than None.
#
#  def testMissingEncodingDeclaration(self):
#    loggedEvents=[]
#    self._assertEqualUnicode(xmlEncoding.decode(ctAX, None, '<?xml version="1.0"?><x/>', loggedEvents), u'<?xml version="1.0"?><x/>')
#    self.assertEquals(len(loggedEvents), 1)
#    self.assertEquals(loggedEvents[0].__class__, MissingEncoding, "Must warn if there's no clue as to encoding")

  def testJustDeclaration(self):
    loggedEvents=[]
    self._assertEqualUnicode(xmlEncoding.decode(ctAX, None, '<?xml version="1.0" encoding="utf-8"?><x/>', loggedEvents), u'<?xml version="1.0" encoding="utf-8"?><x/>')
    self.assertEquals(loggedEvents, [])

  def testSupplyUnknownEncoding(self):
    loggedEvents=[]
    self.assertEquals(xmlEncoding.decode(ctAX, 'X-FAKE', '<x/>', loggedEvents), None)
    self.assertEquals(len(loggedEvents), 1)
    self.assertEquals(loggedEvents[0].__class__, UnknownEncoding, 'Must fail if an unknown encoding is used')

  def testDeclareUnknownEncoding(self):
    loggedEvents=[]
    self.assertEquals(xmlEncoding.decode(ctAX, None, '<?xml version="1.0" encoding="X-FAKE"?><x/>', loggedEvents), None)
    self.assert_(loggedEvents)
    self.assertEquals(loggedEvents[-1].__class__, UnknownEncoding)

  def testWarnMismatch(self):
    loggedEvents=[]
    self.assertEquals(xmlEncoding.decode(ctAX, 'US-ASCII', '<?xml version="1.0" encoding="UTF-8"?><x/>', loggedEvents), u'<?xml version="1.0" encoding="UTF-8"?><x/>')
    self.assert_(loggedEvents)
    self.assertEquals(loggedEvents[-1].__class__, EncodingMismatch)

  def testDecodeUTF8(self):
    loggedEvents=[]
    self.assertEquals(xmlEncoding.decode(ctAX, 'utf-8', '<x>\xc2\xa3</x>', loggedEvents), u'<x>\u00a3</x>')
    self.assertEquals(loggedEvents, [])

  def testDecodeBadUTF8(self):
    """Ensure bad UTF-8 is flagged as such, but still decoded."""
    loggedEvents=[]
    self.assertEquals(xmlEncoding.decode(ctAX, 'utf-8', '<x>\xa3</x>', loggedEvents), u'<x>\ufffd</x>')
    self.assert_(loggedEvents)
    self.assertEquals(loggedEvents[-1].__class__, UnicodeError)

  def testRemovedBOM(self):
    """Make sure the initial BOM signature is not in the decoded string."""
    loggedEvents=[]
    self.assertEquals(xmlEncoding.decode(ctAX, 'UTF-16', '\xff\xfe\x3c\x00\x78\x00\x2f\x00\x3e\x00', loggedEvents), u'<x/>')
    self.assertEquals(loggedEvents, [])


class TestRemoveDeclaration(unittest.TestCase):
  def testRemoveSimple(self):
    self.assertEqual(xmlEncoding.removeDeclaration(
        '<?xml version="1.0" encoding="utf-8"?>'),
        '<?xml version="1.0"                 ?>')

    self.assertEqual(xmlEncoding.removeDeclaration(
      "<?xml version='1.0' encoding='us-ascii'  ?>"),
      "<?xml version='1.0'                      ?>")

  def testNotRemoved(self):
    """Make sure that invalid, or missing, declarations aren't affected."""
    for x in [
      '<?xml encoding="utf-8"?>', # Missing version
      '<doc />', # No declaration
      ' <?xml version="1.0" encoding="utf-8"?>' # Space before declaration
    ]:
      self.assertEqual(xmlEncoding.removeDeclaration(x), x)

if __name__ == "__main__":
  unittest.main()
