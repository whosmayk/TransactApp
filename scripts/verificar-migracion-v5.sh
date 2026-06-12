#!/bin/bash
# verificar-migracion-v5.sh
# Compara valores monetarios antes y despues de la migracion REAL->INTEGER.
# Uso: bash scripts/verificar-migracion-v5.sh

set -e

DB="$1"
if [ -z "$DB" ]; then
    DB=~/Library/Application\ Support/TransactApp/transactapp.sqlite
fi

if [ ! -f "$DB" ]; then
    echo "ERROR: $DB no existe"
    exit 1
fi

BACKUP="${DB%.sqlite}_pre_v5.sqlite"
cp "$DB" "$BACKUP"
echo "Backup: $BACKUP"

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

export_baseline() {
    local db=$1
    local suf=$2
    sqlite3 "$db" ".headers off" "
    SELECT 'tx', id, concepto, printf('%.2f', ROUND(monto * 100) / 100.0)
    FROM Transacciones ORDER BY id;
    " > "$TMP/tx_${suf}.csv"

    sqlite3 "$db" ".headers off" "
    SELECT 'pr', id, persona,
           printf('%.2f', ROUND(monto * 100) / 100.0),
           printf('%.2f', ROUND(montoPagado * 100) / 100.0)
    FROM Prestamos ORDER BY id;
    " > "$TMP/pr_${suf}.csv"

    sqlite3 "$db" ".headers off" "
    SELECT 'su', id, concepto, printf('%.2f', ROUND(monto * 100) / 100.0)
    FROM Suscripciones ORDER BY id;
    " > "$TMP/su_${suf}.csv"

    sqlite3 "$db" ".headers off" "
    SELECT 'si', 1, 'efectivo', printf('%.2f', ROUND(efectivo * 100) / 100.0)
    FROM SaldoInicial
    UNION ALL
    SELECT 'sit', 1, 'tarjeta', printf('%.2f', ROUND(tarjeta * 100) / 100.0)
    FROM SaldoInicial;
    " > "$TMP/si_${suf}.csv"
}

echo "=== Exportando baseline pre-migracion ==="
export_baseline "$DB" "pre"

echo ""
echo "=== Aplicando migracion v5 ==="
sqlite3 "$DB" "
ALTER TABLE Transacciones ADD COLUMN monto_temp INTEGER NOT NULL DEFAULT 0;
UPDATE Transacciones SET monto_temp = CAST(ROUND(monto * 100) AS INTEGER);
ALTER TABLE Transacciones DROP COLUMN monto;
ALTER TABLE Transacciones RENAME COLUMN monto_temp TO monto;

ALTER TABLE Prestamos ADD COLUMN monto_temp INTEGER NOT NULL DEFAULT 0;
UPDATE Prestamos SET monto_temp = CAST(ROUND(monto * 100) AS INTEGER);
ALTER TABLE Prestamos DROP COLUMN monto;
ALTER TABLE Prestamos RENAME COLUMN monto_temp TO monto;

ALTER TABLE Prestamos ADD COLUMN montoPagado_temp INTEGER NOT NULL DEFAULT 0;
UPDATE Prestamos SET montoPagado_temp = CAST(ROUND(montoPagado * 100) AS INTEGER);
ALTER TABLE Prestamos DROP COLUMN montoPagado;
ALTER TABLE Prestamos RENAME COLUMN montoPagado_temp TO montoPagado;

ALTER TABLE Suscripciones ADD COLUMN monto_temp INTEGER NOT NULL DEFAULT 0;
UPDATE Suscripciones SET monto_temp = CAST(ROUND(monto * 100) AS INTEGER);
ALTER TABLE Suscripciones DROP COLUMN monto;
ALTER TABLE Suscripciones RENAME COLUMN monto_temp TO monto;

ALTER TABLE SaldoInicial ADD COLUMN efectivo_temp INTEGER NOT NULL DEFAULT 0;
UPDATE SaldoInicial SET efectivo_temp = CAST(ROUND(efectivo * 100) AS INTEGER);
ALTER TABLE SaldoInicial DROP COLUMN efectivo;
ALTER TABLE SaldoInicial RENAME COLUMN efectivo_temp TO efectivo;

ALTER TABLE SaldoInicial ADD COLUMN tarjeta_temp INTEGER NOT NULL DEFAULT 0;
UPDATE SaldoInicial SET tarjeta_temp = CAST(ROUND(tarjeta * 100) AS INTEGER);
ALTER TABLE SaldoInicial DROP COLUMN tarjeta;
ALTER TABLE SaldoInicial RENAME COLUMN tarjeta_temp TO tarjeta;
"

echo "=== Exportando baseline post-migracion ==="
export_baseline "$DB" "post"

echo ""
echo "=== Comparando ==="
FAIL=0
for tabla in tx pr su si; do
    if ! diff "$TMP/${tabla}_pre.csv" "$TMP/${tabla}_post.csv"; then
        echo "ERROR: $tabla difiere"
        FAIL=1
    else
        echo "OK: $tabla identico"
    fi
done

echo ""
echo "=== Restaurando backup ==="
cp "$BACKUP" "$DB"

if [ $FAIL -eq 0 ]; then
    echo ""
    echo "=== VERIFICACION EXITOSA ==="
    echo "La migracion preserva todos los valores monetarios."
else
    echo ""
    echo "=== VERIFICACION FALLIDA ==="
    echo "Revisa las diferencias arriba."
    exit 1
fi
