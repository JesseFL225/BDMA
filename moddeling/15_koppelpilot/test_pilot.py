"""Synthetic unit tests for the Step 15 linkage rules: time window, station overlap,
shared-hub rejection, time zones, ambiguous candidates and exclusion of detour stations."""
import unittest
import csv,io
from pathlib import Path
from pilot import candidates_for, parse_message, stamp, normalize_cause

class LinkageChecks(unittest.TestCase):
    def setUp(self):
        self.r={'rdt_id':'1','start_time':'2023-11-10T12:00:00Z','rdt_station_codes':'ASD, SHL'}
        self.m=dict(dossier='NS-99',published='2023-11-10T12:00:01Z',received='2023-11-10T12:00:02Z',
          available='2023-11-10T12:00:02Z',station_codes='ASD|SHL',sequence='1',phase='1B',source_file='fixture',source_line=1)
    def test_large_archive_xml_field(self):
        field="x"*200000
        self.assertEqual(next(csv.reader(io.StringIO("a,b,"+field+",d")))[2],field)
    def test_cause_wording_is_not_substantive_change(self):
        self.assertEqual(normalize_cause("een verstoring elders"),normalize_cause("verstoring elders"))
        self.assertNotEqual(normalize_cause("eerdere verstoring"),normalize_cause("seinstoring"))
    def test_time_and_station_evidence(self):
        self.assertTrue(candidates_for(self.r,[self.m])[0]['eligible'])
        m=dict(self.m,station_codes='UT|AMF')
        self.assertFalse(candidates_for(self.r,[m])[0]['eligible'])
        m=dict(self.m,published='2023-11-10T12:02:01Z')
        self.assertFalse(candidates_for(self.r,[m])[0]['eligible'])
    def test_shared_hub_insufficient(self):
        m=dict(self.m,station_codes='ASD|UT')
        self.assertFalse(candidates_for(self.r,[m])[0]['eligible'])
    def test_boundary_and_timezone(self):
        m=dict(self.m,published='2023-11-10T13:02:00+01:00')
        self.assertTrue(candidates_for(self.r,[m])[0]['eligible'])
        with self.assertRaises(ValueError):stamp('2023-11-10T12:00:00')
    def test_multiple_candidates_remain_visible(self):
        self.assertEqual(sum(c['eligible'] for c in candidates_for(self.r,[self.m,dict(self.m,dossier='NS-100')])),2)
    def test_availability_and_advisory_exclusion(self):
        xml='''<root><ReisInformatieTijdstip>2023-11-10T12:00:01Z</ReisInformatieTijdstip>
        <LandelijkePatroonInformatie><DossierNummer>9</DossierNummer><VrijgaveTijd>2023-11-10T12:00:03Z</VrijgaveTijd>
        <Situatie><BaanvakBeperking><StationVan><StationCode>ASD</StationCode></StationVan></BaanvakBeperking>
        <OmreisAdvies><StationCode>UT</StationCode></OmreisAdvies></Situatie></LandelijkePatroonInformatie></root>'''
        m,_=parse_message(['2023-11-10T12:00:02+00:00','',xml,'hash'],Path('fixture'),1)
        self.assertEqual(m['available'],'2023-11-10T12:00:03+00:00')
        self.assertEqual(m['station_codes'],'ASD')

if __name__=='__main__':unittest.main()
