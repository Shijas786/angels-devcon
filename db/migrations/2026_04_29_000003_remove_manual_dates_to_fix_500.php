<?php

declare(strict_types=1);

namespace Engelsystem\Migrations;

use Engelsystem\Database\Migration\Migration;

class RemoveManualDatesToFix500 extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $db = $this->schema->getConnection();
        
        // Remove the hardcoded strings that break the Carbon timestamp casting
        $db->table('event_config')
            ->whereIn('name', ['buildup_start', 'event_start', 'event_end', 'teardown_end'])
            ->delete();
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No down migration
    }
}
