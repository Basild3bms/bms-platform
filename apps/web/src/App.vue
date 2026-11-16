<script setup lang="ts">
import { onMounted, ref } from 'vue'

const apiStatus = ref('Checking API…')

onMounted(async () => {
  try {
    const response = await fetch('/api/v1/status')
    if (!response.ok) throw new Error(`HTTP ${response.status}`)
    const payload: { status: string } = await response.json()
    apiStatus.value = payload.status === 'ok' ? 'API online' : 'API unavailable'
  } catch {
    apiStatus.value = 'API unavailable'
  }
})
</script>

<template>
  <main>
    <header><span class="mark">BMS</span><span class="badge">M1 development</span></header>
    <section class="hero">
      <p class="eyebrow">Building operations</p>
      <h1>Platform foundation</h1>
      <p>Commercial building monitoring and control will appear here as the platform milestones are completed.</p>
      <div class="status"><span class="dot"></span>{{ apiStatus }}</div>
    </section>
    <section class="grid" aria-label="Planned modules">
      <article><h2>Portfolio</h2><p>Organizations, buildings and spaces</p></article>
      <article><h2>Operations</h2><p>Devices, telemetry and alarms</p></article>
      <article><h2>Energy</h2><p>Usage, trends and reporting</p></article>
    </section>
  </main>
</template>
