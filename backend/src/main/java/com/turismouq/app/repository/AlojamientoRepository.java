package com.turismouq.app.repository;

import com.turismouq.app.entity.Alojamiento;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AlojamientoRepository extends JpaRepository<Alojamiento, Long> {
    List<Alojamiento> findAllByOrderByNombreAsc();
    List<Alojamiento> findByMunicipioIdMunicipioOrderByNombreAsc(Long idMunicipio);
}
