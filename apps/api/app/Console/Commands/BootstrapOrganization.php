<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

#[Signature('bms:bootstrap-organization {--name=} {--slug=} {--email=}')]
#[Description('Create a local organization and its first owner; prompts for the password')]
class BootstrapOrganization extends Command
{
    public function handle(): int
    {
        if (! app()->environment(['local', 'testing'])) {
            $this->error('Bootstrap is available only in local or test environments.');

            return self::FAILURE;
        }

        $password = $this->secret('Owner password');
        $data = [
            'name' => $this->option('name'), 'slug' => $this->option('slug'),
            'email' => Str::lower(trim((string) $this->option('email'))), 'password' => $password,
        ];
        $validator = Validator::make($data, [
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['required', 'alpha_dash', 'max:255', 'unique:organizations,slug'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:12', 'max:128'],
        ]);
        if ($validator->fails()) {
            $this->error($validator->errors()->first());

            return self::FAILURE;
        }

        DB::transaction(function () use ($data): void {
            $organizationId = (string) Str::uuid();
            DB::table('organizations')->insert([
                'id' => $organizationId, 'name' => $data['name'], 'slug' => $data['slug'],
                'timezone' => 'UTC', 'created_at' => now(), 'updated_at' => now(),
            ]);
            $user = User::create([
                'name' => $data['name'].' owner', 'email' => Str::lower($data['email']),
                'password' => $data['password'],
            ]);
            $membershipId = (string) Str::uuid();
            DB::table('organization_memberships')->insert([
                'id' => $membershipId, 'organization_id' => $organizationId,
                'user_id' => $user->id, 'role' => 'owner', 'active' => true,
                'created_at' => now(), 'updated_at' => now(),
            ]);
            DB::table('audit_events')->insert([
                'id' => (string) Str::uuid(), 'organization_id' => $organizationId,
                'actor_user_id' => $user->id, 'action' => 'organization.bootstrapped',
                'subject_type' => 'organization', 'subject_id' => $organizationId,
                'created_at' => now(),
            ]);
        });

        $this->info('Organization and owner created.');

        return self::SUCCESS;
    }
}
