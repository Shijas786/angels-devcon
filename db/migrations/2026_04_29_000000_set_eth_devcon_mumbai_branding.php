<?php

declare(strict_types=1);

namespace Engelsystem\Migrations;

use Engelsystem\Database\Migration\Migration;
use Illuminate\Database\Schema\Blueprint;

class SetEthDevConMumbaiBranding extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $db = $this->schema->getConnection();
        
        $db->table('event_config')->updateOrInsert(
            ['name' => 'name'],
            ['name' => 'name', 'value' => json_encode('ETH DevCon Mumbai 2026')]
        );
        
        $db->table('event_config')->updateOrInsert(
            ['name' => 'app_name'],
            ['name' => 'app_name', 'value' => json_encode('ETH DevCon Mumbai')]
        );

        $db->table('event_config')->updateOrInsert(
            ['name' => 'theme'],
            ['name' => 'theme', 'value' => json_encode(22)]
        );
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No down migration
    }
}
