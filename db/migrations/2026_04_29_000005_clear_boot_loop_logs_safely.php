<?php

declare(strict_types=1);

namespace Engelsystem\Migrations;

use Engelsystem\Database\Migration\Migration;

class ClearBootLoopLogsSafely extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $db = $this->schema->getConnection();
        
        // Use delete() instead of truncate() to avoid MySQL foreign key constraint errors
        $db->table('log_entries')->delete();
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No down migration
    }
}
