<?php

declare(strict_types=1);

namespace Engelsystem\Migrations;

use Engelsystem\Database\Migration\Migration;

class SetEthDevConMumbaiDates extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $db = $this->schema->getConnection();
        
        // Push the shifts from June to November
        $db->table('shifts')->update([
            'start' => $db->raw("REPLACE(start, '2026-06-', '2026-11-0')"),
            'end'   => $db->raw("REPLACE(end, '2026-06-', '2026-11-0')")
        ]);

        // Fix the specific days (e.g. 15th to 3rd, 16th to 4th)
        $db->table('shifts')->update([
            'start' => $db->raw("REPLACE(start, '-11-015', '-11-03')"),
            'end'   => $db->raw("REPLACE(end, '-11-015', '-11-03')")
        ]);
        $db->table('shifts')->update([
            'start' => $db->raw("REPLACE(start, '-11-016', '-11-04')"),
            'end'   => $db->raw("REPLACE(end, '-11-016', '-11-04')")
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No down migration
    }
}
