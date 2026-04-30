<?php

declare(strict_types=1);

namespace Engelsystem\Migrations;

use Engelsystem\Database\Migration\Migration;

class ClearBootLoopLogs extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $db = $this->schema->getConnection();
        
        // Truncate the log entries to wipe out the 200+ critical boot-loop errors
        // from the `setTimezone() on null` crash.
        $db->table('log_entries')->truncate();
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No down migration
    }
}
