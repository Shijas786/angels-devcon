<?php

declare(strict_types=1);

namespace Engelsystem\Database;

use Carbon\Carbon;
use Engelsystem\Config\Config;
use Engelsystem\Container\ServiceProvider;
use Exception;
use Illuminate\Database\Capsule\Manager as CapsuleManager;
use Illuminate\Database\Connection as DatabaseConnection;
use PDO;
use PDOException;
use Throwable;

class DatabaseServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        /** @var Config $config */
        $config = $this->app->get('config');
        /** @var CapsuleManager $capsule */
        $capsule = $this->app->make(CapsuleManager::class);
        $now = Carbon::now($config->get('timezone'));

        // Build base config from the application config
        $dbConfig = array_merge([
            'driver'    => 'mysql',
            'host'      => '',
            'database'  => '',
            'username'  => '',
            'password'  => '',
            'charset'   => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'timezone'  => $now->format('P'),
            'prefix'    => '',
        ], $config->get('database', []));

        // Final authoritative override from environment variables.
        // This ensures Railway/Docker env vars always win, bypassing any
        // config-chain flattening issues. env() falls back through all known
        // Railway variable name variants.
        $envHost = getenv('MYSQL_HOST') ?: getenv('MYSQLHOST') ?: getenv('DB_HOST') ?: null;
        $envPort = getenv('MYSQL_PORT') ?: getenv('MYSQLPORT') ?: getenv('DB_PORT') ?: '3306';
        $envDb   = getenv('MYSQL_DATABASE') ?: getenv('MYSQLDATABASE') ?: getenv('DB_DATABASE') ?: null;
        $envUser = getenv('MYSQL_USER') ?: getenv('MYSQLUSER') ?: getenv('DB_USERNAME') ?: getenv('DB_USER') ?: null;
        $envPass = getenv('MYSQL_PASSWORD') ?: getenv('MYSQLPASSWORD') ?: getenv('DB_PASSWORD') ?: null;

        if ($envHost !== null) { $dbConfig['host']     = $envHost; }
        if ($envPort)          { $dbConfig['port']     = (int) $envPort; }
        if ($envDb !== null)   { $dbConfig['database'] = $envDb; }
        if ($envUser !== null) { $dbConfig['username'] = $envUser; }
        if ($envPass !== null) { $dbConfig['password'] = $envPass; }

        $capsule->addConnection($dbConfig);

        $capsule->setAsGlobal();
        $capsule->bootEloquent();
        $capsule->getConnection()->useDefaultSchemaGrammar();

        $pdo = null;
        try {
            $pdo = $capsule->getConnection()->getPdo();

            // Disable ONLY_FULL_GROUP_BY to prevent errors from legacy GROUP BY queries
            // that don't list all non-aggregated columns in the SELECT clause.
            $pdo->exec("SET SESSION sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''))");
        } catch (PDOException $e) {
            $dsn = "mysql:host=" . ($dbConfig['host'] ?? '') . ";port=" . ($dbConfig['port'] ?? '') . ";dbname=" . ($dbConfig['database'] ?? '');
            $errorMsg = "DB Connection Failed. DSN: $dsn, User: " . ($dbConfig['username'] ?? '') . ". Error: " . $e->getMessage();
            throw new Exception($errorMsg, (int)$e->getCode(), $e);
        }

        $this->app->instance(PDO::class, $pdo);
        $this->app->instance(CapsuleManager::class, $capsule);
        $this->app->instance(Db::class, $capsule);
        Db::setDbManager($capsule);

        $connection = $capsule->getConnection();
        $this->app->instance(DatabaseConnection::class, $connection);

        $database = $this->app->make(Database::class);
        $this->app->instance(Database::class, $database);
        $this->app->instance('db', $database);
        $this->app->instance('db.pdo', $pdo);
        $this->app->instance('db.connection', $connection);
    }

    /**
     *
     * @throws Exception
     */
    protected function exitOnError(Throwable $exception): void
    {
        throw new Exception('Error: Unable to connect to database', 0, $exception);
    }
}
