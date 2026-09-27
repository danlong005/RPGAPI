"""examples/memberships.sqlrpgle: a row as JSON built by JSON_OBJECT. Creates
the table TESTDTA the example reads, in the test library."""
from common import *
import json, os, subprocess

args = setup(__doc__)
lib = os.environ.get('RPGAPI_TEST_LIB', 'RPGAPI')

def sql(statement):
    command = f"RUNSQL SQL('{statement.replace(chr(39), chr(39) * 2)}') COMMIT(*NONE)"
    return subprocess.run(['system', command], capture_output=True, text=True).stdout

sql(f'drop table {lib}.testdta')
sql(f'create table {lib}.testdta (id decimal(11, 0) not null primary key, fname char(25), lname char(25))')
sql(f"insert into {lib}.testdta values (1, 'Anna', 'Berg'), (2, 'Jo \"JJ\"', 'O\\Brien'), (3, 'Jürgen', 'Groß')")

def member(id):
    status, headers, body = get(f'/api/v1/memberships/{id}')
    try:
        return status, headers.get('content-type'), json.loads(body)
    except ValueError:
        return status, headers.get('content-type'), body

check('a row as JSON', member(1) == (200, 'application/json', {'id': 1, 'first_name': 'Anna', 'last_name': 'Berg'}),
      member(1))
check('quotes and a backslash escaped by JSON_OBJECT',
      member(2)[2] == {'id': 2, 'first_name': 'Jo "JJ"', 'last_name': 'O\\Brien'}, member(2))
check('umlaut and sharp s', member(3)[2] == {'id': 3, 'first_name': 'Jürgen', 'last_name': 'Groß'}, member(3))
check('no such row: 404 with a JSON error', member(9)[0] == 404 and member(9)[2] == {'error': 'no such membership'},
      member(9))
sql(f'drop table {lib}.testdta')
done()
