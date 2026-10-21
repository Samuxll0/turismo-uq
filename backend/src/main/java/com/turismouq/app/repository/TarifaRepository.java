package com.turismouq.app.repository;

import com.turismouq.app.entity.Tarifa;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TarifaRepository extends JpaRepository<Tarifa, Long> {
    List<Tarifa> findByHabitacionIdHabitacion(Long idHabitacion);
    Optional<Tarifa> findByHabitacionIdHabitacionAndIdTemporada(Long idHabitacion, Long idTemporada);
}
