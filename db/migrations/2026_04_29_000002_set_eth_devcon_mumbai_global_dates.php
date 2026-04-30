<?php

declare(strict_types=1);

namespace Engelsystem\Migrations;

use Engelsystem\Database\Migration\Migration;

class SetEthDevConMumbaiGlobalDates extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $db = $this->schema->getConnection();
        
        // Force global event dates immediately via migration
        $db->table('event_config')->updateOrInsert(
            ['name' => 'buildup_start'],
            ['name' => 'buildup_start', 'value' => json_encode('2026-11-01')]
        );
        $db->table('event_config')->updateOrInsert(
            ['name' => 'event_start'],
            ['name' => 'event_start', 'value' => json_encode('2026-11-03')]
        );
        $db->table('event_config')->updateOrInsert(
            ['name' => 'event_end'],
            ['name' => 'event_end', 'value' => json_encode('2026-11-06')]
        );
        $db->table('event_config')->updateOrInsert(
            ['name' => 'teardown_end'],
            ['name' => 'teardown_end', 'value' => json_encode('2026-11-07')]
        );

        // Delete the old shifts so the entrypoint script can re-seed the correct November ones
        $db->table('shifts')->delete();
        $db->table('needed_angel_types')->delete();
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No down migration
    }
}
